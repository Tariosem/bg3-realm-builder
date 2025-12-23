KeybindMenu = KeybindMenu or {}

KeybindMenu = {
    parent = nil,
    panel = nil,
    isAttach = true,
    isVisible = false,
}

local KEYBIND_MODULE_RENDER_ORDER = {
    "GeneralShortcuts",
    "TransformToolbar",
    "TransformEditor",
    "BindUtility",
}

local KEYBIND_EVENT_RENDER_ORDER = {
    GeneralShortcuts = {
        "OpenMainMenu",
        "OpenBrowserMenu",
        "OpenTransformToolbar",
        "OpenVisualTab",
        "DeleteAllGizmos",
    },
    TransformToolbar = {
        "MultiSelect",
        "BoxSelect",
        "Select",
        "ClearSelection",
        "DeleteSelection",
        "Duplicate",
        "HideSelection",
        "ShowSelection",
        "ApplyGravity",
        "FreezeGravity",
        "SnapToGround",
        "OpenNearbyPopup",
        "Undo",
        "Redo",
    },
    TransformEditor = {
        "CycleMode",
        "Grab",
        "Rotate",
        "Scale",
        "FollowTarget",
    },
    BindUtility = {
        "BindPopup",
        "BindTo",
        "Unbind",
        "SnapToHover",
    },
}

local localizedNames = {
    GeneralShortcuts = "Genetal Shortcuts",

    OpenMainMenu = "Toggle Main Menu",
    OpenBrowserMenu = "Toggle Browser Menu",
    OpenTransformToolbar = "Toggle Transform Toolbar",
    OpenVisualTab = "Open Visual Tab",
    DeleteAllGizmos = "Clear All Gizmos",

    TransformToolbar = "Transform Toolbar",

    MultiSelect = "Multi Select",
    BoxSelect = "Box Select",
    Select = "Select",
    ClearSelection = "Clear Selection",
    DeleteSelection = "Delete Selection",
    Duplicate = "Duplicate Selection",
    HideSelection = "Hide Selection",
    ShowSelection = "Show Selection",
    ApplyGravity = "Apply Gravity",
    FreezeGravity = "Freeze Gravity",
    SnapToGround = "Snap To Ground",
    OpenNearbyPopup = "Open Nearby Popup",
    MoveToCursor = "Move To Cursor",
    Move3DCursor = "Move 3D Cursor",
    Snap3DCursor = "Snap 3D Cursor",
    SnapToHover = "Snap To Hover",
    Undo = "Undo",
    Redo = "Redo",

    TransformEditor = "Transform Editor",

    CycleMode = "Cycle Mode",
    Grab = "Grab",
    Rotate = "Rotate",
    Scale = "Scale",
    FollowTarget = "Follow target",

    BindUtility = "Bind Utility",

    BindPopup = "Open Bind Popup",
    BindTo = "Bind To Hover",
    Unbind = "Unbind Selection",

}

function KeybindMenu:Render(parent)
    self.parent = parent or self.parent

    if self.isAttach and self.parent then
        self.panel = parent:AddTabItem(GetLoca("Keybind"))
        self.isWindow = false
        self:OnAttach()
    else
        self.panel = WindowManager.RegisterWindow("generic", "Keybind", "Menu", self)
        self.panel.AlwaysAutoResize = true
        self.isWindow = true
        self:OnDetach()
    end

    self:RenderFileMenu()
    self.rootTable = self.panel:AddTable("KetbindMenu", 1)

    self.isVisible = true

    self:RenderContents()
end

function KeybindMenu:RenderFileMenu()
    local saveBtn = self.panel:AddButton("Save Keybindings")
    saveBtn.OnClick = function()
        KeybindManager:SaveToFile()
    end

    local loadBtn = self.panel:AddButton("Load Keybindings")
    loadBtn.SameLine = true
    loadBtn.OnClick = function()
        KeybindManager:LoadFromFile()
    end
end

function KeybindMenu:RenderContents()
    local modules = KeybindManager.Modules
    local order = KEYBIND_MODULE_RENDER_ORDER or {}

    local orderedSet = {}
    for _, name in ipairs(order) do
        orderedSet[name] = true
    end

    for _, name in ipairs(order) do
        local module = modules[name]
        if module then
            self:RenderModule(module)
        end
    end

    for name, module in pairs(modules) do
        if not orderedSet[name] then
            self:RenderModule(module)
        end
    end
end

--- @param t ExtuiTable
local function applyTableStyle(t)
    t.RowBg = true
    t.Borders = true
    t.ColumnDefs[1] = { WidthFixed = true }
    t.ColumnDefs[2] = { WidthStretch = true }
    t.ColumnDefs[3] = { WidthFixed = true }
    t.ColumnDefs[4] = { WidthFixed = true }

    --t:SetColor("TableRowBg", HexToRGBA("#2C2C2C"))
    --t:SetColor("TableRowBgAlt", HexToRGBA("#3C3C3C"))
    --t:SetColor("TableBorderStrong", HexToRGBA("#1C1C1C"))
end

local function applyHeaderStyle(header)
    --header:SetColor("Header", HexToRGBA("#333333"))
    --header:SetColor("HeaderHovered", HexToRGBA("#444444"))
    --header:SetColor("HeaderActive", HexToRGBA("#555555"))
    --header:SetColor("Text", HexToRGBA("#FFFFFF"))
    --header:SetColor("TextDisabled", HexToRGBA("#AAAAAA"))
end

--- @param module KeybindModule
function KeybindMenu:RenderModule(module)
    local name = module.Name
    local row = self.rootTable:AddRow()
    local cell = row:AddCell()
    local localName = GetLoca(localizedNames[name] or name)
    local header = cell:AddCollapsingHeader(localName)
    header.DefaultOpen = true
    local tTable = header:AddTable("", 4)
    applyTableStyle(tTable)
    applyHeaderStyle(header)

    local events = module:GetEvents()
    local order = KEYBIND_EVENT_RENDER_ORDER[name] or {}

    local orderedSet = {}
    for _, ev in ipairs(order) do
        orderedSet[ev] = true
    end

    for _, eventName in ipairs(order) do
        local registry = events[eventName]
        if registry then
            local row = tTable:AddRow()
            self:RenderEvent(row, module.Name, eventName, module, registry)
        end
    end

    for eventName, registry in pairs(events) do
        if not orderedSet[eventName] then
            local row = tTable:AddRow()
            self:RenderEvent(row, module.Name, eventName, module, registry)
        end
    end
end

--- @param keybind Keybinding
local function getPresentation(keybind)
    if not keybind then
        return "Unbound"
    end

    local parts = {}
    if keybind.Modifiers then
        for _, mod in pairs(keybind.Modifiers) do
            table.insert(parts, Enums.ModfierToPresentation[mod] or mod)
        end
    end
    table.insert(parts, Enums.InputCodeToPresentation[keybind.Key] or keybind.Key)

    for i, part in ipairs(parts) do
        parts[i] = "[" .. part .. "]"
    end

    return table.concat(parts, " + ")
end

local conflictNotif = Notification.new("Keybind Conflict")
conflictNotif.Pivot = { 0.5, 0.5 }
conflictNotif.ClickToDismiss = true
conflictNotif.ChangeDirectionWhenFadeOut = true

---@param row ExtuiTableRow
---@param moduleName string
---@param eventName string
---@param module KeybindModule
---@param registry KeybindRegistry
function KeybindMenu:RenderEvent(row, moduleName, eventName, module, registry)
    local enableCell, eventCell, keyCell, resetCell = row:AddCell(), row:AddCell(), row:AddCell(), row:AddCell()

    local enableCheckBox = enableCell:AddCheckbox("", not registry.Disabled)

    enableCheckBox.OnChange = function(check)
        registry.Disabled = not check.Checked
    end

    --enableCheckBox:SetColor("Text", HexToRGBA("#FFFFFF"))
    --enableCheckBox:SetColor("CheckMark", HexToRGBA("D5284CCF"))
    --enableCheckBox:SetColor("FrameBg", HexToRGBA("49011947"))
    --enableCheckBox:SetColor("FrameBgHovered", HexToRGBA("785575B5"))
    --enableCheckBox:SetColor("FrameBgActive", HexToRGBA("FF355081"))

    local localizedEventName = GetLoca(localizedNames[eventName] or eventName)
    eventCell:AddText(localizedEventName) --:SetColor("Text", HexToRGBA("#FFFFFF"))

    if registry.Description then
        local desc = ImguiElements.AddIndent(eventCell):AddText(registry.Description)
        desc.TextWrapPos = 900

        desc:SetColor("Text", ColorUtils.HexToRGBA("#CCCCCC"))
        desc.Font = "Tiny"
    end

    local initKeybind = module:GetKeyByEvent(eventName)

    local keybindText = getPresentation(initKeybind)

    local keyButton = keyCell:AddButton(keybindText) --[[@as ExtuiSelectable]]

    keyButton.OnClick = function()
        local originLabel = keyButton.Label
        keyButton.Label = "Press any key..."
        keyButton.Disabled = true
        module:RebindByInput(eventName, function(newKeybind, conflictModule, conflictEvent)
            if not newKeybind then
                local conflictKeybind = KeybindManager:GetKeyByEvent(conflictModule, conflictEvent)
                conflictNotif:Show("Keybind Conflict", function(panel)
                    local notigSel = panel:AddSelectable(getPresentation(conflictKeybind or {}))
                    notigSel.Font = "Large"
                    notigSel:SetColor("Text", { 1, 1, 1, 1 })
                    notigSel:SetStyle("SelectableTextAlign", 0.5, 0)
                    notigSel.SelectableDisabled = true
                    panel:AddText("Is already bound to "):SetColor("Text", { 1, 1, 1, 1 })
                    local modTex = panel:AddBulletText(conflictModule)
                    modTex:SetColor("Text", { 0.7, 0.7, 0.7, 1 })
                    modTex.Font = "Large"
                    local tex = panel:AddText(conflictEvent)
                    tex:SetColor("Text", { 1, 1, 1, 1 })
                    tex.SameLine = true
                    tex.Font = "Large"
                end)
                keyButton.Disabled = false
                keyButton.Label = originLabel
                return
            end
            keyButton.Label = getPresentation(newKeybind)
            keyButton.Disabled = false
        end)
    end

    ImguiElements.AddResetButton(resetCell, false).OnClick = function()
        local defaultKeybind = initKeybind or {}
        module:Rebind(eventName, defaultKeybind.Key, defaultKeybind.Modifiers)
        keyButton.Label = getPresentation(module:GetKeyByEvent(eventName))
    end
end

function KeybindMenu:Collapsed()
    if not self.isVisible then
        return
    end

    if self.panel and self.isWindow then
        WindowManager.DeleteWindow(self.panel)
        self.panel = nil
    else
        self.panel:Destroy()
        self.panel = nil
    end
    self.isVisible = false
end

function KeybindMenu:OnAttach()
end

function KeybindMenu:OnDetach()
end
