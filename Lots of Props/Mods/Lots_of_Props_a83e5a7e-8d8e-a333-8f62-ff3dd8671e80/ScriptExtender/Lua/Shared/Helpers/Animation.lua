--- @enum AnimationEasing
AnimationEasing = {
    Linear = "Linear",

    Ease = "Ease",
    EaseIn = "EaseIn",
    EaseOut = "EaseOut",
    EaseInOut = "EaseInOut",

    EaseInQuad = "EaseInQuad",
    EaseOutQuad = "EaseOutQuad",
    EaseInOutQuad = "EaseInOutQuad",

    EaseInCubic = "EaseInCubic",
    EaseOutCubic = "EaseOutCubic",
    EaseInOutCubic = "EaseInOutCubic",

    EaseInQuart = "EaseInQuart",
    EaseOutQuart = "EaseOutQuart",
    EaseInOutQuart = "EaseInOutQuart",

    EaseInQuint = "EaseInQuint",
    EaseOutQuint = "EaseOutQuint",
    EaseInOutQuint = "EaseInOutQuint",

    EaseInExpo = "EaseInExpo",
    EaseOutExpo = "EaseOutExpo",
    EaseInOutExpo = "EaseInOutExpo",

    EaseInBounce = "EaseInBounce",
    EaseOutBounce = "EaseOutBounce",
    EaseInOutBounce = "EaseInOutBounce",

    EaseInSine = "EaseInSine",
    EaseOutSine = "EaseOutSine",
    EaseInOutSine = "EaseInOutSine",

    EaseInBack = "EaseInBack",
    EaseOutBack = "EaseOutBack",
    EaseInOutBack = "EaseInOutBack",
}

-- https://cubic-bezier.com/
-- B(t) = (1-t)³P0 + 3(1-t)²tP1 + 3(1-t)t²P2 + t³P3
local function CubicBezier(p0, p1, p2, p3, t)
    local u = 1 - t
    return u^3 * p0 + 3 * u^2 * t * p1 + 3 * u * t^2 * p2 + t^3 * p3
end

local function MakeBezierEasing(p1y, p2y)
    return function(t)
        return CubicBezier(0, p1y, p2y, 1, t)
    end
end

local EasingFuncs = {}

local function genratePowerEasing(pow, name)
    EasingFuncs["EaseIn" .. name] = function(t) return t^pow end
    EasingFuncs["EaseOut" .. name] = function(t) return 1 - (1 - t)^pow end
    EasingFuncs["EaseInOut" .. name] = function(t)
        if t < 0.5 then
            return (2 * t)^pow / 2
        else
            return 1 - (-2 * t + 2)^pow / 2
        end
    end
end

genratePowerEasing(2, "Quad")
genratePowerEasing(3, "Cubic")
genratePowerEasing(4, "Quart")
genratePowerEasing(5, "Quint")

EasingFuncs = {
    Linear = function(t) return t end,

    EaseIn = MakeBezierEasing(0.42, 1.0),
    EaseOut = MakeBezierEasing(0.0, 0.58),
    EaseInOut = MakeBezierEasing(0.42, 0.58),

    EaseInExpo = function(t)
        return t == 0 and 0 or 2^(10 * t - 10)
    end,
    EaseOutExpo = function(t)
        return t == 1 and 1 or 1 - 2^(-10 * t)
    end,
    EaseInOutExpo = function(t)
        if t == 0 then return 0 end
        if t == 1 then return 1 end
        if t < 0.5 then
            return 2^(20 * t - 10) / 2
        else
            return (2 - 2^(-20 * t + 10)) / 2
        end
    end,

    EaseOutBounce = function(t)
        local n1, d1 = 7.5625, 2.75
        if t < 1 / d1 then
            return n1 * t * t
        elseif t < 2 / d1 then
            t = t - 1.5 / d1
            return n1 * t * t + 0.75
        elseif t < 2.5 / d1 then
            t = t - 2.25 / d1
            return n1 * t * t + 0.9375
        else
            t = t - 2.625 / d1
            return n1 * t * t + 0.984375
        end
    end,
    EaseInBounce = function(t)
        return 1 - EasingFuncs.EaseOutBounce(1 - t)
    end,
    EaseInOutBounce = function(t)
        if t < 0.5 then
            return (1 - EasingFuncs.EaseOutBounce(1 - 2 * t)) / 2
        else
            return (1 + EasingFuncs.EaseOutBounce(2 * t - 1)) / 2
        end
    end,

    EaseInSine = function(t)
        return 1 - math.cos((t * math.pi) / 2)
    end,
    EaseOutSine = function(t)
        return math.sin((t * math.pi) / 2)
    end,
    EaseInOutSine = function(t)
        return -(math.cos(math.pi * t) - 1) / 2
    end,

    EaseInBack = function(t)
        local c1, c3 = 1.70158, 2.70158
        return c3 * t^3 - c1 * t^2
    end,
    EaseOutBack = function(t)
        local c1, c3 = 1.70158, 2.70158
        t = t - 1
        return 1 + c3 * t^3 + c1 * t^2
    end,
    EaseInOutBack = function(t)
        local c2 = 2.5949095
        if t < 0.5 then
            return ((2 * t) ^ 2 * ((c2 + 1) * 2 * t - c2)) / 2
        else
            t = t - 1
            return ((2 * t) ^ 2 * ((c2 + 1) * 2 * t + c2) + 2) / 2
        end
    end,
}

--- @class RunningAnimation
--- @field Stop fun():number, number
--- @field Get fun():number, number
--- @field GetLast fun():number, number  

--- @param fps number
--- @param fromValue number|Vec
--- @param toValue number|Vec
--- @param duration number ms
--- @param easing AnimationEasing|string
--- @param onComplete fun()|nil
--- @param onUpdate fun(value: number|number[], eased: number)|nil
--- @return RunningAnimation?
function AnimateValue(fps, fromValue, toValue, duration, easing, onComplete, onUpdate)
    if type(fromValue) == "table" or type(toValue) == "table" then
        if type(fromValue) ~= "table" or type(toValue) ~= "table" then
            Warning("Invalid input format") 
            return nil
        elseif #fromValue ~= #toValue then
            Warning("Non matching vector") 
            return nil
        end
        fromValue = Vector.new(fromValue)
        toValue = Vector.new(toValue)
    end
        
    fps = math.max(fps or 90, 1)
    duration = math.max(duration or 1000, 1)

    local startTime = Ext.Utils.MonotonicTime()
    local frameDelay = 1000 / (fps or 90)
    local easingFunc = EasingFuncs[easing] or EasingFuncs[AnimationEasing[easing]] or EasingFuncs.Linear
    local canceled = false
    local cancelValue, cancelEased = fromValue, 0
    local errorCount = 0
    local maxErrors = 5

    local pcallOnUpdate = function(value, eased)
        if onUpdate then
            local ok, err = pcall(function()
                onUpdate(value, eased)
            end)
            if not ok then
                --Error(err)
                errorCount = errorCount + 1
            end
            if errorCount >= maxErrors then
                --Error("Too many errors in onFrame, stopping animation")
                canceled = true
            end
        end
    end

    local pcallOnComplete = function()
        if onComplete then
            local ok, err = pcall(function()
                onComplete()
            end)
            if not ok then
                --Error(err)
            end
        end
    end

    local function step()
        if canceled then return end

        local elapsed = Ext.Utils.MonotonicTime() - startTime
        local progress = math.min(elapsed / duration, 1.0)
        local eased = easingFunc(progress)
        local currentValue = fromValue + (toValue - fromValue) * eased

        cancelValue = currentValue
        cancelEased = eased

        pcallOnUpdate(currentValue, eased)

        if progress < 1 then
            Timer:After(frameDelay, step)
        else
            pcallOnUpdate(currentValue, eased)
            pcallOnComplete()
        end
    end

    local function CancelAnimation()
        canceled = true
        return cancelValue, cancelEased
    end

    local function GetCurrent()
        local elapsed = Ext.Utils.MonotonicTime() - startTime
        local progress = math.min(elapsed / duration, 1.0)
        local eased = easingFunc(progress)
        local currentValue = fromValue + (toValue - fromValue) * eased
        return currentValue, eased
    end

    local function GetLast()
        return cancelValue, cancelEased
    end

    step()

    return {
        Stop = CancelAnimation,
        Get = GetCurrent,
        GetLast = GetLast,
    }
end

function GetAllEasings(namdDescend)
    local easings = {}
    for k,_ in pairs(AnimationEasing) do
        if type(k) == "string" then
            table.insert(easings, k)
        end
    end
    table.sort(easings, namdDescend and function(a,b) return a>b end or function(a,b) return a<b end)
    return easings
end