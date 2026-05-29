--- @alias BoneName string
--- @alias GenomeVariableName string

--- @enum SupportedSkeletons 
SUPPORTED_SKELETONS = {
    NormieSkeleton = "NormieSkeleton",
    NormieTailSkeleton = "NormieTailSkeleton",
}

--- @class BoneDefine
--- @field Parent string?
--- @field Position vec3?
--- @field Rotation quat?
--- @field Scale vec3?
--- @field LocalMatrix mat4?

--- @alias SkeletonDefine table<BoneName, BoneDefine>

--- @type SkeletonDefine
local normie_skeleton = {
    ["Dummy_Root"] = {
        Parent = nil,
    },
    ["Dummy_R_Foot_IK"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_L_Foot_IK"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_R_Hand_IK"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_L_Hand_IK"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_HitImpactFX"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_FollowPhysics"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_Custom_Anim"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_Playerlight"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_OverheadFX"] = {
        Parent = "Dummy_Root",
    },
    ["Dummy_CastFX"] = {
        Parent = "Dummy_Root",
    },
    ["Root_M"] = {
        Parent = "Dummy_Root",
    },
    ["Hip_R"] = {
        Parent = "Root_M",
    },
    ["Knee_R"] = {
        Parent = "Hip_R",
    },
    ["Dummy_R_KneeFX_01"] = {
        Parent = "Knee_R",
    },
    ["Ankle_R"] = {
        Parent = "Knee_R",
    },
    ["Toes_R"] = {
        Parent = "Ankle_R",
    },
    ["ToesEnd_R_endBone"] = {
        Parent = "Toes_R",
    },
    ["Dummy_R_Foot_01"] = {
        Parent = "Toes_R",
    },
    ["Hip_R_Twist_01"] = {
        Parent = "Hip_R",
    },
    ["Hip_R_Twist_02"] = {
        Parent = "Hip_R_Twist_01",
    },
    ["Hip_L"] = {
        Parent = "Root_M",
    },
    ["Knee_L"] = {
        Parent = "Hip_L",
    },
    ["Dummy_L_KneeFX_01"] = {
        Parent = "Knee_L",
    },
    ["Ankle_L"] = {
        Parent = "Knee_L",
    },
    ["Toes_L"] = {
        Parent = "Ankle_L",
    },
    ["Dummy_L_Foot_01"] = {
        Parent = "Toes_L",
    },
    ["ToesEnd_L_endBone"] = {
        Parent = "Toes_L",
    },
    ["Hip_L_Twist_01"] = {
        Parent = "Hip_L",
    },
    ["Hip_L_Twist_02"] = {
        Parent = "Hip_L_Twist_01",
    },
    ["Spine1_M"] = {
        Parent = "Root_M",
    },
    ["Spine2_M"] = {
        Parent = "Spine1_M",
    },
    ["Chest_M"] = {
        Parent = "Spine2_M",
    },
    ["Scapula_R"] = {
        Parent = "Chest_M",
    },
    ["Shoulder_R"] = {
        Parent = "Scapula_R",
    },
    ["Elbow_R"] = {
        Parent = "Shoulder_R",
    },
    ["Dummy_R_TentacleFX"] = {
        Parent = "Elbow_R",
    },
    ["Elbow_Twist_R"] = {
        Parent = "Elbow_R",
    },
    ["Wrist_R"] = {
        Parent = "Elbow_R",
    },
    ["Dummy_R_Hand"] = {
        Parent = "Wrist_R",
    },
    ["Dummy_R_HandFX"] = {
        Parent = "Wrist_R",
    },
    ["RingFinger0_R"] = {
        Parent = "Wrist_R",
    },
    ["RingFinger1_R"] = {
        Parent = "RingFinger0_R",
    },
    ["RingFinger2_R"] = {
        Parent = "RingFinger1_R",
    },
    ["RingFinger3_R"] = {
        Parent = "RingFinger2_R",
    },
    ["RingFinger4_R_endBone"] = {
        Parent = "RingFinger3_R",
    },
    ["ThumbFinger1_R"] = {
        Parent = "Wrist_R",
    },
    ["ThumbFinger2_R"] = {
        Parent = "ThumbFinger1_R",
    },
    ["ThumbFinger3_R"] = {
        Parent = "ThumbFinger2_R",
    },
    ["ThumbFinger4_R_endBone"] = {
        Parent = "ThumbFinger3_R",
    },
    ["PinkyFinger0_R"] = {
        Parent = "Wrist_R",
    },
    ["PinkyFinger1_R"] = {
        Parent = "PinkyFinger0_R",
    },
    ["PinkyFinger2_R"] = {
        Parent = "PinkyFinger1_R",
    },
    ["PinkyFinger3_R"] = {
        Parent = "PinkyFinger2_R",
    },
    ["PinkyFinger4_R_endBone"] = {
        Parent = "PinkyFinger3_R",
    },
    ["MiddleFinger1_R"] = {
        Parent = "Wrist_R",
    },
    ["MiddleFinger2_R"] = {
        Parent = "MiddleFinger1_R",
    },
    ["MiddleFinger3_R"] = {
        Parent = "MiddleFinger2_R",
    },
    ["MiddleFinger4_R_endBone"] = {
        Parent = "MiddleFinger3_R",
    },
    ["IndexFinger1_R"] = {
        Parent = "Wrist_R",
    },
    ["IndexFinger2_R"] = {
        Parent = "IndexFinger1_R",
    },
    ["IndexFinger3_R"] = {
        Parent = "IndexFinger2_R",
    },
    ["IndexFinger4_R_endBone"] = {
        Parent = "IndexFinger3_R",
    },
    ["Shoulder_Twist_R"] = {
        Parent = "Shoulder_R",
    },
    ["Shoulder_R_Twist_01"] = {
        Parent = "Shoulder_R",
    },
    ["Shoulder_R_Twist_02"] = {
        Parent = "Shoulder_R_Twist_01",
    },
    ["Shoulder_Boo_R"] = {
        Parent = "Scapula_R",
    },
    ["Scapula_L"] = {
        Parent = "Chest_M",
    },
    ["Shoulder_L"] = {
        Parent = "Scapula_L",
    },
    ["Elbow_L"] = {
        Parent = "Shoulder_L",
    },
    ["Elbow_Twist_L"] = {
        Parent = "Elbow_L",
    },
    ["Dummy_L_TentacleFX"] = {
        Parent = "Elbow_L",
    },
    ["Wrist_L"] = {
        Parent = "Elbow_L",
    },
    ["Dummy_L_HandFX"] = {
        Parent = "Wrist_L",
    },
    ["Dummy_L_Hand"] = {
        Parent = "Wrist_L",
    },
    ["RingFinger0_L"] = {
        Parent = "Wrist_L",
    },
    ["RingFinger1_L"] = {
        Parent = "RingFinger0_L",
    },
    ["RingFinger2_L"] = {
        Parent = "RingFinger1_L",
    },
    ["RingFinger3_L"] = {
        Parent = "RingFinger2_L",
    },
    ["RingFinger4_L_endBone"] = {
        Parent = "RingFinger3_L",
    },
    ["ThumbFinger1_L"] = {
        Parent = "Wrist_L",
    },
    ["ThumbFinger2_L"] = {
        Parent = "ThumbFinger1_L",
    },
    ["ThumbFinger3_L"] = {
        Parent = "ThumbFinger2_L",
    },
    ["ThumbFinger4_L_endBone"] = {
        Parent = "ThumbFinger3_L",
    },
    ["PinkyFinger0_L"] = {
        Parent = "Wrist_L",
    },
    ["PinkyFinger1_L"] = {
        Parent = "PinkyFinger0_L",
    },
    ["PinkyFinger2_L"] = {
        Parent = "PinkyFinger1_L",
    },
    ["PinkyFinger3_L"] = {
        Parent = "PinkyFinger2_L",
    },
    ["PinkyFinger4_L_endBone"] = {
        Parent = "PinkyFinger3_L",
    },
    ["MiddleFinger1_L"] = {
        Parent = "Wrist_L",
    },
    ["MiddleFinger2_L"] = {
        Parent = "MiddleFinger1_L",
    },
    ["MiddleFinger3_L"] = {
        Parent = "MiddleFinger2_L",
    },
    ["MiddleFinger4_L_endBone"] = {
        Parent = "MiddleFinger3_L",
    },
    ["IndexFinger1_L"] = {
        Parent = "Wrist_L",
    },
    ["IndexFinger2_L"] = {
        Parent = "IndexFinger1_L",
    },
    ["IndexFinger3_L"] = {
        Parent = "IndexFinger2_L",
    },
    ["IndexFinger4_L_endBone"] = {
        Parent = "IndexFinger3_L",
    },
    ["Shoulder_Twist_L"] = {
        Parent = "Shoulder_L",
    },
    ["Shoulder_L_Twist_01"] = {
        Parent = "Shoulder_L",
    },
    ["Shoulder_L_Twist_02"] = {
        Parent = "Shoulder_L_Twist_01",
    },
    ["Shoulder_Boo_L"] = {
        Parent = "Scapula_L",
    },
    ["Dummy_Sheath_Music"] = {
        Parent = "Chest_M",
    },
    ["Dummy_ChestFX"] = {
        Parent = "Chest_M",
    },
    ["Dummy_Sheath_Upper_L"] = {
        Parent = "Chest_M",
    },
    ["Dummy_Sheath_Upper_R"] = {
        Parent = "Chest_M",
    },
    ["Dummy_WingFX"] = {
        Parent = "Chest_M",
    },
    ["Neck_M"] = {
        Parent = "Chest_M",
    },
    ["Head_M"] = {
        Parent = "Neck_M",
    },
    ["Dummy_EyeFX_02"] = {
        Parent = "Head_M",
    },
    ["Dummy_EyeFX_01"] = {
        Parent = "Head_M",
    },
    ["Dummy_HeadFX"] = {
        Parent = "Head_M",
    },
    ["Dummy_MouthFX"] = {
        Parent = "Head_M",
    },
    ["Dummy_StatusFX"] = {
        Parent = "Head_M",
    },
    ["HeadEnd_M_endBone"] = {
        Parent = "Head_M",
    },
    ["Dummy_NeckFX"] = {
        Parent = "Neck_M",
    },
    ["Dummy_Sheath_Ranged"] = {
        Parent = "Spine2_M",
    },
    ["Dummy_Sheath_Shield"] = {
        Parent = "Spine2_M",
    },
    ["Dummy_BodyFX"] = {
        Parent = "Spine1_M",
    },
    ["Dummy_Sheath_Lower_L"] = {
        Parent = "Spine1_M",
    },
    ["Dummy_Sheath_Lower_R"] = {
        Parent = "Spine1_M",
    },
    ["Dummy_Sheath_Hip_L"] = {
        Parent = "Root_M",
    },
    ["Dummy_Sheath_Hip_R"] = {
        Parent = "Root_M",
    },
}

--- @type SkeletonDefine
local normie_tail_skelton = {
    ["Dummy_Root"] = {
        Parent = nil,
    },
    ["Root_M"] = {
        Parent = "Dummy_Root",
    },
    ["Tail0_M"] = {
        Parent = "Root_M",
    },
    ["Tail1_M"] = {
        Parent = "Tail0_M",
    },
    ["Tail2_M"] = {
        Parent = "Tail1_M",
    },
    ["Tail3_M"] = {
        Parent = "Tail2_M",
    },
    ["Tail4_M"] = {
        Parent = "Tail3_M",
    },
    ["Tail5_M"] = {
        Parent = "Tail4_M",
    },
    ["Tail6_M"] = {
        Parent = "Tail5_M",
    },
    ["Tail7_M"] = {
        Parent = "Tail6_M",
    },
    ["Tail8_endBone"] = {
        Parent = "Tail7_M",
    },
    ["Spine1_M"] = {
        Parent = "Root_M",
    },
    ["Spine2_M"] = {
        Parent = "Spine1_M",
    },
    ["Hip_L"] = {
        Parent = "Root_M",
    },
    ["Hip_L_Twist_01"] = {
        Parent = "Hip_L",
    },
    ["Hip_R"] = {
        Parent = "Root_M",
    },
    ["Hip_R_Twist_01"] = {
        Parent = "Hip_R",
    },
}

--- @type table<SupportedSkeletons, SkeletonDefine>
return {
    NormieSkeleton = normie_skeleton,
    NormieTailSkeleton = normie_tail_skelton,
}