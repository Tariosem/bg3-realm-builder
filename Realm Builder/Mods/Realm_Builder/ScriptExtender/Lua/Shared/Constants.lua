RB_GLOBALS = RB_GLOBALS or {}

GUID_NULL = "00000000-0000-0000-0000-000000000000"

RB_PROP_TAG = "02131330-7126-43c4-b5a3-b619e42dcf50"
RB_GIZMO_TAG = "08f54bd8-3029-4faa-9f2f-cef3160a44c0"

RB_PROP_AXIS_FX = "RB_Gizmo_Translate_347586d3-e55e-4cea-8d26-168d17e233c6"

RB_BEAM_ITEM_FX = "18e043e7-45e7-4eb0-b201-cdd78e38528a"

GIZMO_ITEM = {
    Translate = "RB_Gizmo_Translate_347586d3-e55e-4cea-8d26-168d17e233c6",
    Rotate = "RB_Gizmo_Rotate_8bc16a4a-f135-485b-a226-641012b7450a",
    Scale = "RB_Gizmo_Scale_723a815e-801a-4792-aa80-0fd65b599a24",
}

GIZMO_CURSOR = "4a39a1c5-26c3-44ab-9410-4080c5dbc2aa"

MARKER_ITEM = {
    SpotLight = "RB_SpotLight_Marker_4cc17738-e9a9-4cda-a2a2-953220d535a9",
    PointLight = "RB_PointLight_Marker_1bca30fb-aa71-48ad-afa4-33582bde984b",
}

GIZMO_TEXTURE = {
    X = "81d77dbe-4c56-cca9-229c-a625393c8d54", --RB_Gizmo_X_Red_
    Y = "edca009e-ca14-952d-a288-ac264b8b4af7", --RB_Gizmo_Y_Green_
    Z = "5bba49f3-5f8b-9929-7231-586a9eedbb24", --RB_Gizmo_Z_Blue_
}

GIZMO_TEXTURE_TO_AXIS = {}

for axis,texture in pairs(GIZMO_TEXTURE) do
    GIZMO_TEXTURE_TO_AXIS[texture] = axis
end

INVISIBLE_HELPER_SCENERY = "3d4e8434-f972-4080-8602-66b12e2949f2"
INVISIBLE_HELPER_PREVIEW = "9e28abea-a971-4aae-ab97-c161ed663c99"
INVISIBLE_HELPER_VISUAL = "7cc1fdbe-a0c1-4003-acec-07f26b5efe4b"

--- @enum RB_ICONS
RB_ICONS = {}
RB_ICONS.Character = "RB_Character_Icon"
RB_ICONS.Scenery = "RB_Scenery_Icon"
RB_ICONS.Character_Fill = "RB_Character_Icon_Fill"
RB_ICONS.Scenery_Fill = "RB_Scenery_Icon_Fill"
RB_ICONS.Character_Standing = "RB_Character_Standing_Icon"
RB_ICONS.Tree_Expanded = "RB_Tree_Expanded_Icon"
RB_ICONS.Tree_Collapsed = "RB_Tree_Collapsed_Icon"
RB_ICONS.Menu_Right = "RB_Menu_Right_Icon"
RB_ICONS.Menu_Down = "RB_Menu_Down_Icon"
RB_ICONS.Tree_Child = "RB_Tree_Child_Icon"
RB_ICONS.Collection = "RB_Collection_Icon"
RB_ICONS.Collection_Fill = "RB_Collection_Icon_Fill"

RB_ICONS.Gear = "RB_Gear_Icon"
RB_ICONS.Gear_Fill = "RB_Gear_Icon_Fill"
RB_ICONS.X_Square = "RB_X_Square_Icon"
RB_ICONS.Sliders = "RB_Sliders_Icon"
RB_ICONS.Copy = "RB_Copy_Icon"
RB_ICONS.Crop = "RB_Crop_Icon"
RB_ICONS.Clipboard = "RB_Clipboard_Icon"

RB_ICONS.Eye = "RB_Eye_Icon"
RB_ICONS.Eye_Slash = "RB_Eye_Slash_Icon"

RB_ICONS.Warning = "RB_Warning_Icon"
RB_ICONS.Exclamation = "RB_Exclamation_Icon"
RB_ICONS.Plus_Square = "RB_Plus_Square_Icon"

RB_ICONS.Three_Dots = "RB_Three_Dots_Icon"
RB_ICONS.Export = "RB_Export_Icon"
RB_ICONS.Import = "RB_Import_Icon"

RB_ICONS.Bounding_Box = "RB_Bounding_Box_Icon"
RB_ICONS.Box = "RB_Box_Icon"
RB_ICONS.Mask = "RB_Mask_Icon"
RB_ICONS.Plus_Circle_Fill = "RB_Plus_Circle_Icon_Fill"

RB_ICONS.Arrow_CounterClockwise = "RB_Arrow_CounterClockwise_Icon"

--- vanilla resources
WARNING_ICON = "PassiveFeature_Generic_Threat"
LOCK_ICON = "Spell_Abjuration_ArcaneLock"

RB_PROP_HIGHLIGHT_FX = "db2affb3-57a7-76f9-9315-d1783cdfc576"
RB_PROP_FIRE_FX = "175786f6-1c13-3051-1001-3cf62d2819aa"
RB_PROP_BIND_VISUALIZATION_FX = "3af9c664-d864-cbcd-e6b1-11ea99e307df" -- Loop beam effect VFX_Beams_Underdark_Arcane_Turret_Beam_01
RB_PROP_BIND_VISUALIZATION_FX_RED = "3e3032d5-dd5c-a9e1-a77c-64273e97a7ce"  -- VFX_Debug_Beam_01


--- @type table<RB_ICONS, {U1:number,U2:number,V1:number,V2:number}>
RB_ICON_UV = {}
RB_ICON_UV[RB_ICONS.Eye] = {
    U1 = 0.12524414,
    U2 = 0.24975586,
    V1 = 0.12524414,
    V2 = 0.24975586,
}
RB_ICON_UV[RB_ICONS.Eye_Slash] = {
    U1 = 0.25024414,
    U2 = 0.37475586,
    V1 = 0.12524414,
    V2 = 0.24975586,
}
RB_ICON_UV[RB_ICONS.Tree_Collapsed] = {
    U1 = 0.25024414,
    U2 = 0.37475586,
    V1 = 0.25024414,
    V2 = 0.37475586,
}
RB_ICON_UV[RB_ICONS.Tree_Expanded] = {
    U1 = 0.37524414,
    U2 = 0.49975586,
    V1 = 0.25024414,
    V2 = 0.37475586,
}
RB_ICON_UV[RB_ICONS.Menu_Right] = {
    U1 = 0.12524414,
    U2 = 0.24975586,
    V1 = 0.37524414,
    V2 = 0.49975586,
}
RB_ICON_UV[RB_ICONS.Menu_Down] = {
    U1 = 0.25024414,
    U2 = 0.37475586,
    V1 = 0.37524414,
    V2 = 0.49975586,
}

--- @type table<RB_ICONS, {UV0:number[],UV1:number[]}>
RB_ICON_UV01 = {}
for icon,data in pairs(RB_ICON_UV) do
    RB_ICON_UV01[icon] = {
        UV0 = {data.U1, data.V1},
        UV1 = {data.U2, data.V2},
    }
end

VANILLA_MODULES = {
    Shared = true,
    Gustav = true,
    SharedDev = true,
    GustavDev = true,
}

EQUIPMENTS_HAS_ARMORTYPE = {
    Boots = true,
    Breast = true,
    Gloves = true,
    Helmet = true,
    Cloak = true,
}

EQUIPMENTS_WEAPONS = {
    ["Melee Main Weapon"] = true,
    ["Melee Offhand Weapon"] = true,
    ["Ranged Main Weapon"] = true,
}

RARITY_COLORS = {
    Common = {0, 0, 0, 0},
    [""] = {0, 0, 0, 0},
    ["None"] = {0, 0, 0, 0},
    Uncommon = HexToRGBA("FF194A1F"),
    Rare = HexToRGBA("FF182A51"),
    VeryRare = HexToRGBA("A48400FF"),
    Legendary = HexToRGBA("FFCA911D"),
    StoryItem = HexToRGBA("AA944300"),
}

DAMAGE_TYPE_COLORS = {
    Acid = HexToRGBA("FFD0F954"),
    Cold = HexToRGBA("FF62D0FF"),
    Fire = HexToRGBA("FFFF5C00"),
    Force = HexToRGBA("FFDC2525"),
    Lightning = HexToRGBA("FF5770FF"),
    Necrotic = HexToRGBA("FF7CFC93"),
    Poison = HexToRGBA("FF4E9331"),
    Psychic = HexToRGBA("FFFFA0DF"),
    Radiant = HexToRGBA("FFFFE680"),
    Thunder = HexToRGBA("FFC758FF"),
    Piercing = HexToRGBA("FFC8C8C8"),
    Slashing = HexToRGBA("FFC8C8C8"),
    Bludgeoning = HexToRGBA("FFC8C8C8"),
    HitPoint = HexToRGBA("FF3DC3BA"),
}

HIGHLIGHT_COLOR = HexToRGBA("FFFED999")
DEBUFF_COLOR = HexToRGBA("FFFF4C4C")
BORDER_COLOR = HexToRGBA("FFFFA43C")

SUBTITLE_COLOR = HexToRGBA("B7939393")

for damageType,color in pairs(DAMAGE_TYPE_COLORS) do
    DAMAGE_TYPE_COLORS[damageType:lower()] = color
end

EPSILON = 0.00001

MOD_DIRECTORY = "Mods/Realm_Builder/"