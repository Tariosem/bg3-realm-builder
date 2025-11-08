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


RB_ICONS = {}
RB_ICONS.Character = "RB_Character_Icon"
RB_ICONS.Scenery = "RB_Scenery_Icon"
RB_ICONS.Character_Fill = "RB_Character_Icon_Fill"
RB_ICONS.Scenery_Fill = "RB_Scenery_Icon_Fill"
RB_ICONS.Tree_Expanded = "RB_Tree_Expanded_Icon"
RB_ICONS.Tree_Collapsed = "RB_Tree_Collapsed_Icon"
RB_ICONS.Tree_Child = "RB_Tree_Child_Icon"
RB_ICONS.Collection = "RB_Collection_Icon"
RB_ICONS.Collection_Fill = "RB_Collection_Icon_Fill"

--- vanilla resources
WARNING_ICON = "PassiveFeature_Generic_Threat"
LOCK_ICON = "Spell_Abjuration_ArcaneLock"

RB_PROP_HIGHLIGHT_FX = "db2affb3-57a7-76f9-9315-d1783cdfc576"
RB_PROP_FIRE_FX = "175786f6-1c13-3051-1001-3cf62d2819aa"
RB_PROP_BIND_VISUALIZATION_FX = "3af9c664-d864-cbcd-e6b1-11ea99e307df" -- Loop beam effect VFX_Beams_Underdark_Arcane_Turret_Beam_01
RB_PROP_BIND_VISUALIZATION_FX_RED = "3e3032d5-dd5c-a9e1-a77c-64273e97a7ce"  -- VFX_Debug_Beam_01

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

DAMAGE_TYPES_COLOR = {
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

for damageType,color in pairs(DAMAGE_TYPES_COLOR) do
    DAMAGE_TYPES_COLOR[damageType:lower()] = color
end

EPSILON = 0.00001

MOD_DIRECTORY = "Mods/Realm_Builder_a83e5a7e-8d8e-a333-8f62-ff3dd8671e80/"