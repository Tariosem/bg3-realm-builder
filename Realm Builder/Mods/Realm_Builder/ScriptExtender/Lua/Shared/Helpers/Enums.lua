UuidToHandle = Ext.Entity.UuidToHandle
HandleToUuid = Ext.Entity.HandleToUuid

Enums = {}

Enums.SDLScanCode = Ext.Enums.SDLScanCode
Enums.SDLKeyModifier = Ext.Enums.SDLKeyModifier

--- @enum GuiColorCategory
local GuiColorCategory = {
    -- StyleColor
    Text = "Color.Text",
    TextDisabled = "Color.Text",
    TextLink = "Color.Text",
    TextSelectedBg = "Color.Text",

    WindowBg = "Color.Background",
    ChildBg = "Color.Background",
    PopupBg = "Color.Background",
    ModalWindowDimBg = "Color.Background",
    TitleBg = "Color.Background",
    TitleBgActive = "Color.Background",
    TitleBgCollapsed = "Color.Background",

    Border = "Color.Border",
    BorderShadow = "Color.Border",

    TableRowBg = "Color.Table",
    TableRowBgAlt = "Color.Table",
    TableBorderLight = "Color.Table",
    TableBorderStrong = "Color.Table",
    TableHeaderBg = "Color.Table",


    Button = "Color.Button",
    ButtonHovered = "Color.Button",
    ButtonActive = "Color.Button",
    CheckMark = "Color.Button",
    MenuBarBg = "Color.Button",

    FrameBg = "Color.Frame",
    FrameBgHovered = "Color.Frame",
    FrameBgActive = "Color.Frame",
    Header = "Color.Frame",
    HeaderHovered = "Color.Frame",
    HeaderActive = "Color.Frame",
    
    SliderGrab = "Color.Slider",
    SliderGrabActive = "Color.Slider",
    ScrollbarBg = "Color.Slider",
    ScrollbarGrab = "Color.Slider",
    ScrollbarGrabHovered = "Color.Slider",
    ScrollbarGrabActive = "Color.Slider",

    ResizeGrip = "Color.Window",
    ResizeGripHovered = "Color.Window",
    ResizeGripActive = "Color.Window",
    
    Tab = "Color.Tab",
    TabHovered = "Color.Tab",
    TabActive = "Color.Tab",
    TabUnfocused = "Color.Tab",
    TabUnfocusedActive = "Color.Tab",
    TabDimmedSelectedOverline = "Color.Tab",

    NavHighlight = "Color.Nav",
    NavWindowingHighlight = "Color.Nav",
    NavWindowingDimBg = "Color.Nav",

    Separator = "Color.Separator",
    SeparatorHovered = "Color.Separator",
    SeparatorActive = "Color.Separator",

    PlotLines = "Color.Plot",
    PlotLinesHovered = "Color.Plot",
    PlotHistogram = "Color.Plot",
    PlotHistogramHovered = "Color.Plot",
}

--- @enum GuiStyleVarCategory
local GuiStyleVarCategory = {
    -- StyleVar
    Alpha = "Var.Global",
    DisabledAlpha = "Var.Global",

    WindowPadding = "Var.Window",
    WindowRounding = "Var.Window",
    WindowBorderSize = "Var.Window",
    WindowMinSize = "Var.Window",
    WindowTitleAlign = "Var.Window",

    ChildRounding = "Var.Child",
    ChildBorderSize = "Var.Child",

    PopupRounding = "Var.Popup",
    PopupBorderSize = "Var.Popup",

    FramePadding = "Var.Frame",
    FrameRounding = "Var.Frame",
    FrameBorderSize = "Var.Frame",
    GrabMinSize = "Var.Frame",
    GrabRounding = "Var.Frame",
    ImageBorderSize = "Var.Frame",

    ScrollbarSize = "Var.Scrollbar",
    ScrollbarRounding = "Var.Scrollbar",

    TabRounding = "Var.Tab",
    TabBorderSize = "Var.Tab",
    TabBarBorderSize = "Var.Tab",
    TabBarOverlineSize = "Var.Tab",

    SeparatorTextAlign = "Var.Separator",
    SeparatorTextBorderSize = "Var.Separator",
    SeparatorTextPadding = "Var.Separator",

    ItemSpacing = "Var.Layout",
    ItemInnerSpacing = "Var.Layout",
    IndentSpacing = "Var.Layout",
    CellPadding = "Var.Layout",

    ButtonTextAlign = "Var.Align",
    SelectableTextAlign = "Var.Align",
    TableAngledHeadersTextAlign = "Var.Align",

    TableAngledHeadersAngle = "Var.Table",
}

--- @alias GuiColorCategories "Color.Text"|"Color.Background"|"Color.Border"|"Color.Table"|"Color.Button"|"Color.Frame"|"Color.Slider"|"Color.Window"|"Color.Nav"|"Color.Tab"|"Color.Separator"|"Color.Plot"|"Color.Other"
--- @alias GuiStyleVarCategories "Var.Global"|"Var.Window"|"Var.Child"|"Var.Popup"|"Var.Frame"|"Var.Scrollbar"|"Var.Tab"|"Var.Separator"|"Var.Layout"|"Var.Align"|"Var.Table"|"Var.Other"

---@return table<GuiColor, GuiColorCategory>
function GetAllGuiColorNames()
    local names = {}
    for _, nameObject in pairs(Ext.Enums.GuiColor) do
        local name = tostring(nameObject)
        names[name] = GuiColorCategory[name] or "Color.Other"
    end

    return names
end

--- @return table<GuiStyleVar, GuiStyleVarCategory>
function GetAllGuiStyleVarNames()
    local names = {}
    for _, nameObject in pairs(Ext.Enums.GuiStyleVar) do
        local name = tostring(nameObject)
        names[name] = GuiStyleVarCategory[name] or "Var.Other"
    end

    return names
end

--- @enum SpellEffectType
Enums.SpellEffectType = {
    BeamEffect = "BeamEffect",
    CastEffect = "CastEffect",
    CastEffectTextEvent = "CastEffectTextEvent",
    DisappearEffect = "DisappearEffect",
    --FemaleImpactEffects
    HitEffect = "HitEffect",
    ImpactEffect = "ImpactEffect",
    --MaleImpactEffects
    PositionEffect = "PositionEffect",
    PrepareEffect = "PrepareEffect",
    PrepareEffectBone = "PrepareEffectBone",
    PreviewEffect = "PreviewEffect",
    ReappearEffect = "ReappearEffect",
    ReappearEffectTextEvent = "ReappearEffectTextEvent",
    SelectedCharacterEffect = "SelectedCharacterEffect",
    SelectedObjectEffect = "SelectedObjectEffect",
    SelectedPositionEffect = "SelectedPositionEffect",
    SpawnEffect = "SpawnEffect",
    SpellEffect = "SpellEffect",
    StormEffect = "StormEffect",
    TargetEffect = "TargetEffect",
    TargetGroundEffect = "TargetHitEffect",
    TargetHitEffect = "TargetHitEffect"
    --WallEndEffect =
    --WallStartEffect =
}

--- @enum StatusEffectType
Enums.StatusEffectType = {
    ApplyEffect = "ApplyEffect",
    AuraFX = "AuraFX",
    BeamEffect = "BeamEffect",
    EndEffect = "EndEffect",
    HealEffectId = "HealEffectId",
    --LEDEffect
    --MeshEffect
    StatusEffect = "StatusEffect",
    StatusEffectOnTurn = "StatusEffectOnTurn",
    StatusEffectOverride = "StatusEffectOverride",
    StatusEffectOverrideForItems = "StatusEffectOverrideForItems",
    TargetEffect = "TargetEffect",
}

Enums.StatusData = Enums.StatusEffectType
Enums.SpellData = Enums.SpellEffectType

EquipmentRaceToBodyType = {
    -- BodyType1
    ["71180b76-5752-4a97-b71f-911a69197f58"] = "BodyType1", -- Human
    ["cf421f4e-107b-4ae6-86aa-090419c624a5"] = "BodyType1", -- Tiefling
    ["ad21d837-2db5-4e46-8393-7d875dd71287"] = "BodyType1", -- Elf
    ["541473b3-0bf3-4e68-b1ab-d85894d96d3e"] = "BodyType1", -- Half-Elf

    -- BodyType2
    ["7d73f501-f65e-46af-a13b-2cacf3985d05"] = "BodyType2", -- Human
    ["6503c830-9200-409a-bd26-895738587a4a"] = "BodyType2", -- Tiefling
    ["7dd0aa66-5177-4f65-b7d7-187c02531b0b"] = "BodyType2", -- Elf
    ["a0737289-ca84-4fde-bd52-25bae4fe8dea"] = "BodyType2", -- Half-Elf

    -- BodyType3
    ["47c0315c-7dc6-4862-b39b-8bf3a10f8b54"] = "BodyType3", -- Human
    ["a5789cd3-ecd6-411b-a53a-368b659bc04a"] = "BodyType3", -- Tiefling
    ["6d38f246-15cb-48b5-9b85-378016a7a78e"] = "BodyType3", -- Dragonborn
    ["eb81b1de-985e-4e3a-8573-5717dc1fa15c"] = "BodyType3", -- Half-Orc
    ["6326d417-315c-4605-964e-d0fad73d719b"] = "BodyType3", -- Karlach

    -- BodyType4
    ["e39505f7-f576-4e70-a99e-8e29cd381a11"] = "BodyType4", -- Human
    ["f625476d-29ec-4a6d-9086-42209af0cf6f"] = "BodyType4", -- Tiefling
    ["6dd3db4f-e2db-4097-b82e-12f379f94c2e"] = "BodyType4", -- Half-Orc
    ["9a8bbeba-850c-402f-bac5-ff15696e6497"] = "BodyType4", -- Dragonborn

    -- ShortBodyType1
    ["b4a34ce7-41be-44d9-8486-938fe1472149"] = "ShortBodyType1", -- Dwarf
    ["8f00cf38-4588-433a-8175-8acdbbf33f33"] = "ShortBodyType1", -- Halfling
    ["c491d027-4332-4fda-948f-4a3df6772baa"] = "ShortBodyType1", -- Gnome

    -- ShortBodyType2
    ["abf674d2-2ea4-4a74-ade0-125429f69f83"] = "ShortBodyType2", -- Dwarf
    ["a933e2a8-aee1-4ecb-80d2-8f47b706f024"] = "ShortBodyType2", -- Halfling
    ["5640e766-aa53-428d-815b-6a0b4ef95aca"] = "ShortBodyType2", -- Gnome

    -- GithyankiBodyType1
    ["06aaae02-bb9e-4fa3-ac00-b08e13a5b0fa"] = "GithyankiBodyType1", -- Githyanki

    -- GithyankiBodyType2
    ["f07faafa-0c6f-4f79-a049-70e96b23d51b"] = "GithyankiBodyType2", -- Githyanki
}

BodyTypeToEquipmentRace = {}

for uuid, bodyType in pairs(EquipmentRaceToBodyType) do
    if not BodyTypeToEquipmentRace[bodyType] then
        BodyTypeToEquipmentRace[bodyType] = {}
    end
    table.insert(BodyTypeToEquipmentRace[bodyType], uuid)
end

--- @enum SimplifiedInputCode
Enums.SimplifiedInputCode = {
    -- Modifiers
    LALT           = "LALT",
    RALT           = "RALT",
    LCTRL          = "LCTRL",
    RCTRL          = "RCTRL",
    LSHIFT         = "LSHIFT",
    RSHIFT         = "RSHIFT",
    LGUI           = "LGUI",
    RGUI           = "RGUI",
    CAPSLOCK       = "CAPSLOCK",
    NUMLOCKCLEAR   = "NUMLOCKCLEAR",
    SCROLLLOCK     = "SCROLLLOCK",

    -- Directional / Navigation
    LEFT           = "LEFT",
    RIGHT          = "RIGHT",
    UP             = "UP",
    DOWN           = "DOWN",
    HOME           = "HOME",
    END            = "END",

    PAGEUP         = "PAGEUP",
    PAGEDOWN       = "PAGEDOWN",
    INSERT         = "INSERT",
    DELETE         = "DELETE",
    DEL            = "DEL",

    -- Function Keys
    F1             = "F1",
    F2             = "F2",
    F3             = "F3",
    F4             = "F4",
    F5             = "F5",
    F6             = "F6",
    F7             = "F7",
    F8             = "F8",
    F9             = "F9",
    F10            = "F10",
    F11            = "F11",
    F12            = "F12",
    F13            = "F13",
    F14            = "F14",
    F15            = "F15",
    F16            = "F16",
    F17            = "F17",
    F18            = "F18",
    F19            = "F19",
    F20            = "F20",
    F21            = "F21",
    F22            = "F22",
    F23            = "F23",
    F24            = "F24",

    -- Alphanumeric Keys
    A              = "A",
    B              = "B",
    C              = "C",
    D              = "D",
    E              = "E",
    F              = "F",
    G              = "G",
    H              = "H",
    I              = "I",
    J              = "J",
    K              = "K",
    L              = "L",
    M              = "M",
    N              = "N",
    O              = "O",
    P              = "P",
    Q              = "Q",
    R              = "R",
    S              = "S",
    T              = "T",
    U              = "U",
    V              = "V",
    W              = "W",
    X              = "X",
    Y              = "Y",
    Z              = "Z",

    -- Punctuation and Symbols
    BACKSLASH      = "BACKSLASH",
    COMMA          = "COMMA",
    PERIOD         = "PERIOD",
    MINUS          = "MINUS",
    EQUALS         = "EQUALS",
    SEMICOLON      = "SEMICOLON",
    APOSTROPHE     = "APOSTROPHE",
    LEFTBRACKET    = "LEFTBRACKET",
    RIGHTBRACKET   = "RIGHTBRACKET",
    GRAVE          = "GRAVE",
    SLASH          = "SLASH",
    NONUSBACKSLASH = "NONUSBACKSLASH",

    -- Numbers
    NUM_0          = "NUM_0",
    NUM_1          = "NUM_1",
    NUM_2          = "NUM_2",
    NUM_3          = "NUM_3",
    NUM_4          = "NUM_4",
    NUM_5          = "NUM_5",
    NUM_6          = "NUM_6",
    NUM_7          = "NUM_7",
    NUM_8          = "NUM_8",
    NUM_9          = "NUM_9",

    -- Special Keys
    RETURN         = "RETURN",
    ESCAPE         = "ESCAPE",
    SPACE          = "SPACE",
    TAB            = "TAB",
    BACKSPACE      = "BACKSPACE",
    PRINTSCREEN    = "PRINTSCREEN",
    PAUSE          = "PAUSE",
    APPLICATION    = "APPLICATION",

    -- Some AC keys (Application Control keys)
    AC_BACK        = "AC_BACK",
    AC_BOOKMARKS   = "AC_BOOKMARKS",
    AC_FORWARD     = "AC_FORWARD",
    AC_HOME        = "AC_HOME",
    AC_REFRESH     = "AC_REFRESH",
    AC_SEARCH      = "AC_SEARCH",
    AC_STOP        = "AC_STOP",

    -- Keypad keys (commonly prefixed with KP_)
    KP_0           = "KP_0",
    KP_1           = "KP_1",
    KP_2           = "KP_2",
    KP_3           = "KP_3",
    KP_4           = "KP_4",
    KP_5           = "KP_5",
    KP_6           = "KP_6",
    KP_7           = "KP_7",
    KP_8           = "KP_8",
    KP_9           = "KP_9",
    KP_ENTER       = "KP_ENTER",
    KP_PLUS        = "KP_PLUS",
    KP_MINUS       = "KP_MINUS",
    KP_MULTIPLY    = "KP_MULTIPLY",
    KP_DIVIDE      = "KP_DIVIDE",
    KP_PERIOD      = "KP_PERIOD",
    KP_EQUALS      = "KP_EQUALS",

    LMB            = "LMB",
    RMB            = "RMB",
    MMB            = "MMB",
}

-- From https://github.com/AtilioA/BG3-MCM/blob/main/Mod%20Configuration%20Menu/Mods/BG3MCM/ScriptExtender/Lua/Shared/Helpers/Keybindings/KeyPresentationMapping.lua
Enums.InputCodeToPresentation = {
    -- Modifiers
    LALT           = "Left Alt",
    RALT           = "Right Alt",
    LCTRL          = "Left Ctrl",
    RCTRL          = "Right Ctrl",
    LSHIFT         = "Left Shift",
    RSHIFT         = "Right Shift",
    LGUI           = "Left Win/Meta",
    RGUI           = "Right Win/Meta",
    CAPSLOCK       = "Caps Lock",
    NUMLOCKCLEAR   = "Num Lock",
    SCROLLLOCK     = "Scroll Lock",

    -- Directional / Navigation
    LEFT           = "Left Arrow",
    RIGHT          = "Right Arrow",
    UP             = "Up Arrow",
    DOWN           = "Down Arrow",

    HOME           = "Home",
    END            = "End",
    PAGEUP         = "Page Up",
    PAGEDOWN       = "Page Down",
    INSERT         = "Insert",
    DELETE         = "Delete",
    DEL            = "Del",

    -- Function Keys
    F1             = "F1",
    F2             = "F2",
    F3             = "F3",
    F4             = "F4",
    F5             = "F5",
    F6             = "F6",
    F7             = "F7",
    F8             = "F8",
    F9             = "F9",
    F10            = "F10",
    F11            = "F11",
    F12            = "F12",
    F13            = "F13",
    F14            = "F14",
    F15            = "F15",
    F16            = "F16",
    F17            = "F17",
    F18            = "F18",
    F19            = "F19",
    F20            = "F20",
    F21            = "F21",
    F22            = "F22",
    F23            = "F23",
    F24            = "F24",

    -- Alphanumeric Keys
    A              = "A",
    B              = "B",
    C              = "C",
    D              = "D",
    E              = "E",
    F              = "F",
    G              = "G",
    H              = "H",
    I              = "I",
    J              = "J",
    K              = "K",
    L              = "L",
    M              = "M",
    N              = "N",
    O              = "O",
    P              = "P",
    Q              = "Q",
    R              = "R",
    S              = "S",
    T              = "T",
    U              = "U",
    V              = "V",
    W              = "W",
    X              = "X",
    Y              = "Y",
    Z              = "Z",

    -- Punctuation and Symbols
    BACKSLASH      = "\\",
    COMMA          = ",",
    PERIOD         = ".",
    MINUS          = "-",
    EQUALS         = "=",
    SEMICOLON      = ";",
    APOSTROPHE     = "'",
    LEFTBRACKET    = "[",
    RIGHTBRACKET   = "]",
    GRAVE          = "`",
    SLASH          = "/",
    NONUSBACKSLASH = "\\",

    -- Numbers
    NUM_0          = "0",
    NUM_1          = "1",
    NUM_2          = "2",
    NUM_3          = "3",
    NUM_4          = "4",
    NUM_5          = "5",
    NUM_6          = "6",
    NUM_7          = "7",
    NUM_8          = "8",
    NUM_9          = "9",

    -- Special Keys
    RETURN         = "Enter",
    ESCAPE         = "Esc",
    SPACE          = "Space",
    TAB            = "Tab",
    BACKSPACE      = "Backspace",
    PRINTSCREEN    = "Print Screen",
    PAUSE          = "Pause",
    APPLICATION    = "Menu",
    -- Additional SDL scan codes can be mapped as needed.

    -- Some AC keys (Application Control keys)
    AC_BACK        = "Back",
    AC_BOOKMARKS   = "Bookmarks",
    AC_FORWARD     = "Forward",
    AC_HOME        = "Home",
    AC_REFRESH     = "Refresh",
    AC_SEARCH      = "Search",
    AC_STOP        = "Stop",

    -- Keypad keys (commonly prefixed with KP_)
    KP_0           = "Keypad 0",
    KP_1           = "Keypad 1",
    KP_2           = "Keypad 2",
    KP_3           = "Keypad 3",
    KP_4           = "Keypad 4",
    KP_5           = "Keypad 5",
    KP_6           = "Keypad 6",
    KP_7           = "Keypad 7",
    KP_8           = "Keypad 8",
    KP_9           = "Keypad 9",
    KP_ENTER       = "Keypad Enter",
    KP_PLUS        = "Keypad +",
    KP_MINUS       = "Keypad -",
    KP_MULTIPLY    = "Keypad *",
    KP_DIVIDE      = "Keypad /",
    KP_PERIOD      = "Keypad .",
    KP_EQUALS      = "Keypad =",

    LMB            = "Left Mouse",
    MMB            = "Middle Mouse",
    RMB            = "Right Mouse",
}

--- @enum SimplifiedModfier
Enums.SimplifiedModfier = {
    LCTRL = "CTRL",
    RCTRL = "CTRL",
    LSHIFT = "SHIFT",
    RSHIFT = "SHIFT",
    LALT = "ALT",
    RALT = "ALT",
    LGUI = "GUI",
    RGUI = "GUI",
    CTRL = "CTRL",
    SHIFT = "SHIFT",
    ALT = "ALT",
    GUI = "GUI",
}

Enums.ModfierToPresentation = {
    CTRL = "Ctrl",
    SHIFT = "Shift",
    ALT = "Alt",
    GUI = "Win/Meta",
}

--- @enum TransformEditorSpace
Enums.TransformEditorSpace = {
    World = "World",
    Local = "Local",
    View = "View",
    Cursor = "Cursor",
    Parent = "Parent"
}

--- @enum TransformEditorMode
Enums.TransformEditorMode = {
    Translate = "Translate",
    Rotate = "Rotate",
    Scale = "Scale",
    Transform = "Transform"
}

--- @enum TransformEditorPivotMode
Enums.TransformEditorPivotMode = {
    Individual = "Individual",
    Median = "Median",
    Cursor = "Cursor",
    Active = "Active"
}

--- @enum TransformAxis
Enums.TransformAxis = {
    X = "X",
    Y = "Y",
    Z = "Z"
}