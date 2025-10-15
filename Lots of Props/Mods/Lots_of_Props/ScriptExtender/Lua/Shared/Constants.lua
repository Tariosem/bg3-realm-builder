LOP_PROP_TAG = "02131330-7126-43c4-b5a3-b619e42dcf50"
LOP_GIZMO_TAG = "08f54bd8-3029-4faa-9f2f-cef3160a44c0"

LOP_PROP_AXIS_FX = "LOP_Gizmo_Translate_347586d3-e55e-4cea-8d26-168d17e233c6"

LOP_BEAM_ITEM_FX = "18e043e7-45e7-4eb0-b201-cdd78e38528a"

GIZMO_ITEM = {
    Translate = "LOP_Gizmo_Translate_347586d3-e55e-4cea-8d26-168d17e233c6",
    Rotate = "LOP_Gizmo_Rotate_8bc16a4a-f135-485b-a226-641012b7450a",
    Scale = "LOP_Gizmo_Scale_723a815e-801a-4792-aa80-0fd65b599a24",
}

GIZMO_TEXTURE = {
    X = "81d77dbe-4c56-cca9-229c-a625393c8d54", --LOP_Gizmo_X_Red_
    Y = "edca009e-ca14-952d-a288-ac264b8b4af7", --LOP_Gizmo_Y_Green_
    Z = "5bba49f3-5f8b-9929-7231-586a9eedbb24", --LOP_Gizmo_Z_Blue_
}

GIZMO_TEXTURE_TO_AXIS = {}

for axis,texture in pairs(GIZMO_TEXTURE) do
    GIZMO_TEXTURE_TO_AXIS[texture] = axis
end

LOOP_SIGN = "cff964c0-eb22-e3a3-d112-130c0aa0c10f"

--- vanilla resources
WARNING_ICON = "PassiveFeature_Generic_Threat"

LOCK_ICON = "Spell_Abjuration_ArcaneLock"

LOP_PROP_HIGHLIGHT_FX = "db2affb3-57a7-76f9-9315-d1783cdfc576"
LOP_PROP_FIRE_FX = "175786f6-1c13-3051-1001-3cf62d2819aa"
LOP_PROP_BIND_VISUALIZATION_FX = "3af9c664-d864-cbcd-e6b1-11ea99e307df" -- Loop beam effect VFX_Beams_Underdark_Arcane_Turret_Beam_01
LOP_PROP_BIND_VISUALIZATION_FX_RED = "3e3032d5-dd5c-a9e1-a77c-64273e97a7ce"  -- VFX_Debug_Beam_01

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
    HitPoint = HexToRGBA("FF75FFF6"),
}

SUBTITLE_COLOR = HexToRGBA("FF939393")

for damageType,color in pairs(DAMAGE_TYPES_COLOR) do
    DAMAGE_TYPES_COLOR[damageType:lower()] = color
end

EPSILON = 0.00001

MOD_DIRECTORY = "Mods/Lots_of_Props_a83e5a7e-8d8e-a333-8f62-ff3dd8671e80/"