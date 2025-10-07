local CameraUpdateTimer = nil
local CameraBindCnt = {}
local cameraSub = nil

local lastPos = {0,0,0}
local lastRot = {0,0,0,1}

local function getAndPostCameraData()
    local cx, cy, cz = GetCameraPosition()
    local cp, cyaw, cr, cw = GetCameraRotation()

    if cx == lastPos[1] and cy == lastPos[2] and cz == lastPos[3]
    and cp == lastRot[1] and cyaw == lastRot[2] and cr == lastRot[3] and cw == lastRot[4] then
        return
    end

    lastPos[1], lastPos[2], lastPos[3] = cx, cy, cz
    lastRot[1], lastRot[2], lastRot[3], lastRot[4] = cp, cyaw, cr, cw

    local postData = {
        CameraPosition = {cx, cy, cz},
        CameraRotation = {cp, cyaw, cr, cw},
    }

    Post("UpdateCamera", postData)
end

local function CameraBind(guid)
    if CameraUpdateTimer == nil then
        getAndPostCameraData()
        CameraUpdateTimer = Timer:EveryFrame(function()
            getAndPostCameraData()
        end)
        Debug("CameraBind: Camera timer started.")
    end

    local data = {
        Guid = guid,
        Type = "Bind",
        Parent = CameraSymbol,
    }

    Post("Bind", data)

    CameraBindCnt[guid] = {}
end

local function DeactiveCameraTimer()
    if CameraUpdateTimer then
        Timer:Cancel(CameraUpdateTimer)
        CameraUpdateTimer = nil
    end

    local data = {
        Type = "DeactiveTimer"
    }

    Post("UpdateCamera", data)
end

local function CameraUnbind(guid)
    CameraBindCnt[guid] = nil

    local count = 0
    for _, _ in pairs(CameraBindCnt) do count = count + 1 end

    if count == 0 then
        DeactiveCameraTimer()
    end
end

if not cameraSub then
    cameraSub = ClientSubscribe("CameraBind", function(data)
        local child = data.Guid

        if data.Type == "Bind" then
            CameraBind(child)
        elseif data.Type == "Unbind" then
            CameraUnbind(child)
        elseif data.Type == "DeactiveTimer" then
            DeactiveCameraTimer()
        end
    end)
end

function StartUpdateingCamera()
    if CameraUpdateTimer == nil then
        CameraUpdateTimer = Timer:EveryFrame(function()
            getAndPostCameraData()
        end)
        Debug("StartUpdateingCamera: Camera timer started.")
    end
end

function StopUpdateingCamera()
    DeactiveCameraTimer()
end

Ext.RegisterConsoleCommand("CameraBindTimer", function (cmd, args)
    if args == "Cancel" then
        DeactiveCameraTimer()
    elseif args == "Start" then
        if CameraUpdateTimer == nil then
            CameraUpdateTimer = Timer:EveryFrame(function()
                local x, y, z = GetCameraPosition()
                local p, yaw, r, w = GetCameraRotation()

                local data = {
                    CameraPosition = {x, y, z},
                    CameraRotation = {p, yaw, r, w}
                }

                Post("UpdateCamera", data)
            end)
        end
    elseif args == "Status" then
        if CameraUpdateTimer then
            _P("CameraBindTimer: Timer is active.")
        else
            _P("CameraBindTimer: Timer is not active.")
        end
    else
        _P("Usage: CameraBindTimer <Start|Cancel|Status>")
    end
end)


