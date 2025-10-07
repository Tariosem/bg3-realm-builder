function Propify(arg)
    if type(arg) == "table" and #arg > 0 then
        for _, item in ipairs(arg) do
            if item then
                Propify(item)
                --Trace("Propified item: " .. tostring(item))
            else
                Warning("Item is nil in items list")
            end
        end
        return true
    elseif arg ~= nil then
        Osi.SetGravity(arg, 1)
        Osi.SetCanInteract(arg, 1)
        Osi.SetVisible(arg, 1)
        Osi.SetMovable(arg, 1)
        Osi.SetTag(arg, LOP_PROP_TAG)
        Osi.SetCanFight(arg, 0)
        Osi.SetCanJoinCombat(arg, 0)
        Osi.ClearTag(arg, LOP_GIZMO_TAG)
        return true
    else
        Error("Propify: input is nil or invalid")
        return false
    end
end

function DrawLine(startPos, endPos, userID)
    if #startPos ~= 3 or #endPos ~= 3 then
        return
    end
    local dir = Ext.Math.Sub(startPos, endPos) -- beam's default direction is -z
    local length = Ext.Math.Length(dir) -- beam's default length is 10

    local toScale = length / 10

    local fxHandle = Osi.CreateAt(LOP_BEAM_ITEM_FX, 0, 0, 0, 0, 0, "") --[[@as string]]

    Osi.SetVisible(fxHandle, 0)
    Timer:Ticks(10, function (timerID)
        if not EntityExists(fxHandle) then
            return
        end
        Osi.SetVisible(fxHandle, 1)
        TeleportTo(fxHandle, startPos[1], startPos[2], startPos[3])
        RotateTo(fxHandle, table.unpack(DirectionToQuat(dir)))

        PostTo(userID, NetMessage.SetVisualTransform, {
            Guid = fxHandle,
            Transforms = {
                [fxHandle] = {
                    Scale = {0.5, 0.5, toScale}
                }
            }
        })
    end)

    return fxHandle
end