--- @enum BonesAlias
local BoneAlias = {
    body = "Dummy_BodyFX",
    head = "Dummy_HeadFX",
    headend = "HeadEnd_M_endBone",
    mouth = "Dummy_MouthFX",
    lefteye = "Dummy_EyeFX_01",
    righteye = "Dummy_EyeFX_02",
    neck = "Dummy_NeckFX",
    status = "Dummy_StatusFX",

    lefthand = "Dummy_L_HandFX",
    righthand = "Dummy_R_HandFX",

    root = "Dummy_Root",
    root_m = "Root_M",

    leftfootik = "Dummy_L_Foot_IK",
    rightfootik = "Dummy_R_Foot_IK",
    lefthandik = "Dummy_L_Hand_IK",
    righthandik = "Dummy_R_Hand_IK",

    hipright = "Hip_R",
    hipleft = "Hip_L",
    kneeright = "Knee_R",
    kneeleft = "Knee_L",
    ankleright = "Ankle_R",
    ankleleft = "Ankle_L",
    toesright = "Toes_R",
    toesleft = "Toes_L",
    toesrightend = "ToesEnd_R_endBone",
    toesleftend = "ToesEnd_L_endBone",

    spine = "Spine1_M",
    spine1 = "Spine1_M",
    spine2 = "Spine2_M",
    chest = "Dummy_ChestFX",

    rightscapula = "Scapula_R",
    leftscapula = "Scapula_L",
    rightshoulder = "Shoulder_R",
    leftshoulder = "Shoulder_L",
    rightelbow = "Elbow_R",
    leftelbow = "Elbow_L",
    rightwrist = "Wrist_R",
    leftwrist = "Wrist_L",

    hit = "Dummy_HitImpactFX",
    followphysics = "Dummy_FollowPhysics",
    customanim = "Dummy_Custom_Anim",
    playerlight = "Dummy_Playerlight",
    overhead = "Dummy_OverheadFX",
    cast = "Dummy_CastFX",
    tentacleright = "Dummy_R_TentacleFX",
    tentacleleft = "Dummy_L_TentacleFX",
    lefttenetacle = "Dummy_L_TentacleFX",
    righttentacle = "Dummy_R_TentacleFX",

    -- Right hand fingers
    rightringfinger0 = "RingFinger0_R",
    rightringfinger1 = "RingFinger1_R",
    rightringfinger2 = "RingFinger2_R",
    rightringfinger3 = "RingFinger3_R",
    rightringfinger  = "RingFinger4_R_endBone",

    rightthumbfinger1 = "ThumbFinger1_R",
    rightthumbfinger2 = "ThumbFinger2_R",
    rightthumbfinger3 = "ThumbFinger3_R",
    rightthumbfinger  = "ThumbFinger4_R_endBone",

    rightpinkyfinger0 = "PinkyFinger0_R",
    rightpinkyfinger1 = "PinkyFinger1_R",
    rightpinkyfinger2 = "PinkyFinger2_R",
    rightpinkyfinger3 = "PinkyFinger3_R",
    rightpinkyfinger  = "PinkyFinger4_R_endBone",

    rightmiddlefinger1 = "MiddleFinger1_R",
    rightmiddlefinger2 = "MiddleFinger2_R",
    rightmiddlefinger3 = "MiddleFinger3_R",
    rightmiddlefinger  = "MiddleFinger4_R_endBone",

    rightindexfinger1 = "IndexFinger1_R",
    rightindexfinger2 = "IndexFinger2_R",
    rightindexfinger3 = "IndexFinger3_R",
    rightindexfinger  = "IndexFinger4_R_endBone",

    -- Left hand fingers
    leftringfinger0 = "RingFinger0_L",
    leftringfinger1 = "RingFinger1_L",
    leftringfinger2 = "RingFinger2_L",
    leftringfinger3 = "RingFinger3_L",
    leftringfinger  = "RingFinger4_L_endBone",

    leftthumbfinger1 = "ThumbFinger1_L",
    leftthumbfinger2 = "ThumbFinger2_L",
    leftthumbfinger3 = "ThumbFinger3_L",
    leftthumbfinger  = "ThumbFinger4_L_endBone",

    leftpinkyfinger0 = "PinkyFinger0_L",
    leftpinkyfinger1 = "PinkyFinger1_L",
    leftpinkyfinger2 = "PinkyFinger2_L",
    leftpinkyfinger3 = "PinkyFinger3_L",
    leftpinkyfinger  = "PinkyFinger4_L_endBone",

    leftmiddlefinger1 = "MiddleFinger1_L",
    leftmiddlefinger2 = "MiddleFinger2_L",
    leftmiddlefinger3 = "MiddleFinger3_L",
    leftmiddlefinger  = "MiddleFinger4_L_endBone",

    leftindexfinger1 = "IndexFinger1_L",
    leftindexfinger2 = "IndexFinger2_L",
    leftindexfinger3 = "IndexFinger3_L",
    leftindexfinger  = "IndexFinger4_L_endBone",

    --Tail
    tail0 = "Tail0_M",
    tail1 = "Tail1_M",
    tail2 = "Tail2_M",
    tail3 = "Tail3_M",
    tail4 = "Tail4_M",
    tail5 = "Tail5_M",
    tail6 = "Tail6_M",
    tail7 = "Tail7_M",
    tail = "Tail8_endBone",

    -- Sheath bones
    sheathmusic       = "Dummy_Sheath_Music",
    sheathupperleft   = "Dummy_Sheath_Upper_L",
    sheathupperright  = "Dummy_Sheath_Upper_R",
    sheathlowerleft   = "Dummy_Sheath_Lower_L",
    sheathlowerright  = "Dummy_Sheath_Lower_R",
    sheathhipleft     = "Dummy_Sheath_Hip_L",
    sheathhipright    = "Dummy_Sheath_Hip_R",
    sheathshield      = "Dummy_Sheath_Shield",
    sheathranged      = "Dummy_Sheath_Ranged",

    wing            = "Dummy_WingFX",
}

--- @enum Bones
local BoneName = {
    Dummy_Root = "Dummy_Root",
    Dummy_R_Foot_IK = "Dummy_R_Foot_IK",
    Dummy_L_Foot_IK = "Dummy_L_Foot_IK",
    Dummy_R_Hand_IK = "Dummy_R_Hand_IK",
    Dummy_L_Hand_IK = "Dummy_L_Hand_IK",
    Dummy_HitImpactFX = "Dummy_HitImpactFX",
    Dummy_FollowPhysics = "Dummy_FollowPhysics",
    Dummy_Custom_Anim = "Dummy_Custom_Anim",
    Dummy_Playerlight = "Dummy_Playerlight",
    Dummy_OverheadFX = "Dummy_OverheadFX",
    Dummy_CastFX = "Dummy_CastFX",
    Root_M = "Root_M",
    Hip_R = "Hip_R",
    Knee_R = "Knee_R",
    Dummy_R_KneeFX_01 = "Dummy_R_KneeFX_01",
    Ankle_R = "Ankle_R",
    Toes_R = "Toes_R",
    ToesEnd_R_endBone = "ToesEnd_R_endBone",
    Dummy_R_Foot_01 = "Dummy_R_Foot_01",
    Hip_R_Twist_01 = "Hip_R_Twist_01",
    Hip_R_Twist_02 = "Hip_R_Twist_02",
    Hip_L = "Hip_L",
    Knee_L = "Knee_L",
    Dummy_L_KneeFX_01 = "Dummy_L_KneeFX_01",
    Ankle_L = "Ankle_L",
    Toes_L = "Toes_L",
    Dummy_L_Foot_01 = "Dummy_L_Foot_01",
    ToesEnd_L_endBone = "ToesEnd_L_endBone",
    Hip_L_Twist_01 = "Hip_L_Twist_01",
    Hip_L_Twist_02 = "Hip_L_Twist_02",
    Spine1_M = "Spine1_M",
    Spine2_M = "Spine2_M",
    Chest_M = "Chest_M",
    Scapula_R = "Scapula_R",
    Shoulder_R = "Shoulder_R",
    Elbow_R = "Elbow_R",
    Dummy_R_TentacleFX = "Dummy_R_TentacleFX",
    Elbow_Twist_R = "Elbow_Twist_R",
    Wrist_R = "Wrist_R",
    Dummy_R_Hand = "Dummy_R_Hand",
    Dummy_R_HandFX = "Dummy_R_HandFX",
    RingFinger0_R = "RingFinger0_R",
    RingFinger1_R = "RingFinger1_R",
    RingFinger2_R = "RingFinger2_R",
    RingFinger3_R = "RingFinger3_R",
    RingFinger4_R_endBone = "RingFinger4_R_endBone",
    ThumbFinger1_R = "ThumbFinger1_R",
    ThumbFinger2_R = "ThumbFinger2_R",
    ThumbFinger3_R = "ThumbFinger3_R",
    ThumbFinger4_R_endBone = "ThumbFinger4_R_endBone",
    PinkyFinger0_R = "PinkyFinger0_R",
    PinkyFinger1_R = "PinkyFinger1_R",
    PinkyFinger2_R = "PinkyFinger2_R",
    PinkyFinger3_R = "PinkyFinger3_R",
    PinkyFinger4_R_endBone = "PinkyFinger4_R_endBone",
    MiddleFinger1_R = "MiddleFinger1_R",
    MiddleFinger2_R = "MiddleFinger2_R",
    MiddleFinger3_R = "MiddleFinger3_R",
    MiddleFinger4_R_endBone = "MiddleFinger4_R_endBone",
    IndexFinger1_R = "IndexFinger1_R",
    IndexFinger2_R = "IndexFinger2_R",
    IndexFinger3_R = "IndexFinger3_R",
    IndexFinger4_R_endBone = "IndexFinger4_R_endBone",
    Shoulder_Twist_R = "Shoulder_Twist_R",
    Shoulder_R_Twist_01 = "Shoulder_R_Twist_01",
    Shoulder_R_Twist_02 = "Shoulder_R_Twist_02",
    Shoulder_Boo_R = "Shoulder_Boo_R",
    Scapula_L = "Scapula_L",
    Shoulder_L = "Shoulder_L",
    Elbow_L = "Elbow_L",
    Elbow_Twist_L = "Elbow_Twist_L",
    Dummy_L_TentacleFX = "Dummy_L_TentacleFX",
    Wrist_L = "Wrist_L",
    Dummy_L_HandFX = "Dummy_L_HandFX",
    Dummy_L_Hand = "Dummy_L_Hand",
    RingFinger0_L = "RingFinger0_L",
    RingFinger1_L = "RingFinger1_L",
    RingFinger2_L = "RingFinger2_L",
    RingFinger3_L = "RingFinger3_L",
    RingFinger4_L_endBone = "RingFinger4_L_endBone",
    ThumbFinger1_L = "ThumbFinger1_L",
    ThumbFinger2_L = "ThumbFinger2_L",
    ThumbFinger3_L = "ThumbFinger3_L",
    ThumbFinger4_L_endBone = "ThumbFinger4_L_endBone",
    PinkyFinger0_L = "PinkyFinger0_L",
    PinkyFinger1_L = "PinkyFinger1_L",
    PinkyFinger2_L = "PinkyFinger2_L",
    PinkyFinger3_L = "PinkyFinger3_L",
    PinkyFinger4_L_endBone = "PinkyFinger4_L_endBone",
    MiddleFinger1_L = "MiddleFinger1_L",
    MiddleFinger2_L = "MiddleFinger2_L",
    MiddleFinger3_L = "MiddleFinger3_L",
    MiddleFinger4_L_endBone = "MiddleFinger4_L_endBone",
    IndexFinger1_L = "IndexFinger1_L",
    IndexFinger2_L = "IndexFinger2_L",
    IndexFinger3_L = "IndexFinger3_L",
    IndexFinger4_L_endBone = "IndexFinger4_L_endBone",
    Shoulder_Twist_L = "Shoulder_Twist_L",
    Shoulder_L_Twist_01 = "Shoulder_L_Twist_01",
    Shoulder_L_Twist_02 = "Shoulder_L_Twist_02",
    Shoulder_Boo_L = "Shoulder_Boo_L",
    Dummy_Sheath_Music = "Dummy_Sheath_Music",
    Dummy_ChestFX = "Dummy_ChestFX",
    Dummy_Sheath_Upper_L = "Dummy_Sheath_Upper_L",
    Dummy_Sheath_Upper_R = "Dummy_Sheath_Upper_R",
    Dummy_WingFX = "Dummy_WingFX",
    Neck_M = "Neck_M",
    Head_M = "Head_M",
    Dummy_EyeFX_02 = "Dummy_EyeFX_02", -- Right eye
    Dummy_EyeFX_01 = "Dummy_EyeFX_01", -- Left eye
    Dummy_HeadFX = "Dummy_HeadFX",
    Dummy_MouthFX = "Dummy_MouthFX",
    Dummy_StatusFX = "Dummy_StatusFX",
    HeadEnd_M_endBone = "HeadEnd_M_endBone",
    Dummy_NeckFX = "Dummy_NeckFX",
    Dummy_Sheath_Ranged = "Dummy_Sheath_Ranged",
    Dummy_Sheath_Shield = "Dummy_Sheath_Shield",
    Dummy_BodyFX = "Dummy_BodyFX",
    Dummy_Sheath_Lower_L = "Dummy_Sheath_Lower_L",
    Dummy_Sheath_Lower_R = "Dummy_Sheath_Lower_R",
    Dummy_Sheath_Hip_L = "Dummy_Sheath_Hip_L",
    Dummy_Sheath_Hip_R = "Dummy_Sheath_Hip_R",
    Tail0_M = "Tail0_M",
    Tail1_M = "Tail1_M",
    Tail2_M = "Tail2_M",
    Tail3_M = "Tail3_M",
    Tail4_M = "Tail4_M",
    Tail5_M = "Tail5_M",
    Tail6_M = "Tail6_M",
    Tail7_M = "Tail7_M",
    Tail8_endBone = "Tail8_endBone",
}

--- @class BoneHelpers
--- @field FindBestMatchBone fun(input:string): (string|nil, table<string>)
--- @field IsBone fun(name:string): boolean
--- @field ParseBoneList fun(bonestr:string, dontFindMatch:boolean?): string
BoneHelpers = BoneHelpers or {}

function BoneHelpers.FindBestMatchBone(input)
    if not input or type(input) ~= "string" or input == "" then
        return nil, {}
    end

    if BoneName[input] then
        return input, { input }
    end

    ---

    local cleanInput = RBStringUtils.ToLowerAlphaOnly(input)
    
    local aliasMatch = BoneAlias[cleanInput]
    if aliasMatch then
        return aliasMatch, { aliasMatch }
    end

    ---

    input = input:lower()

    local candidates = {}

    for name in pairs(BoneName) do
        table.insert(candidates, name)
    end

    for name in pairs(BoneAlias) do
        table.insert(candidates, name)
    end

    local seen = {}
    local uniqueCandidates = {}
    for _, name in ipairs(candidates) do
        if not seen[name] then
            seen[name] = true
            table.insert(uniqueCandidates, name)
        end
    end

    local scores = {}
    for _, name in ipairs(uniqueCandidates) do
        local lname = name:lower()
        local dist = RBStringUtils.Levenshtein(input, lname)

        table.insert(scores, {name = name, score = dist})
    end

    table.sort(scores, function(a, b)
        return a.score < b.score
    end)

    local best = scores[1].name

    if BoneAlias[best] then
        best = BoneAlias[best]
    end

    local topMatches = {}
    for i = 1, math.min(5, #scores) do
        table.insert(topMatches, scores[i].name)
    end

    --_P("Best match for bone '" .. input .. "' is '" .. best .. "' with Levenshtein distance: " .. scores[1].score)

    return best, topMatches
end

function BoneHelpers.IsBone(name)
    return BoneName[name] ~= nil
end

function BoneHelpers.ParseBoneList(bonestr, dontFindMatch)
    if not bonestr or type(bonestr) ~= "string" or bonestr == "" then
        return ""
    end
    
    local results = {}

    for bone in bonestr:gmatch("([^,]+)") do
        local trimmedBone = bone:match("^%s*(.-)%s*$")
        if trimmedBone ~= "" and not dontFindMatch then
            local bestMatch = BoneHelpers.FindBestMatchBone(trimmedBone)
            if bestMatch then
                table.insert(results, bestMatch)
            end
        elseif trimmedBone ~= "" then
            table.insert(results, trimmedBone)
        end
    end
    
    return table.concat(results, ",")
end