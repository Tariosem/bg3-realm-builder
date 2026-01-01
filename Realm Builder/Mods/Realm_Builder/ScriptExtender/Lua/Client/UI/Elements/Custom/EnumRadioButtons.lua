--- @class RadioButtonOption
--- @field Label string
--- @field Value integer
--- @field Tooltip string|nil

--- @class EnumRadioButtonsGroup : ExtuiGroup
--- @field OnChange fun(radioBtn: ExtuiRadioButton, value: integer)
--- @field WrapPos integer
--- @field Value integer

--- @param parent ExtuiTreeParent
--- @param options RadioButtonOption[]
--- @param initValue integer
--- @return EnumRadioButtonsGroup
function ImguiElements.AddBitmaskRadioButtons(parent, options, initValue)
    local group = parent:AddGroup("BitmaskRadioButtonsGroup" .. RBUtils.Uuid_v4())
    local value = initValue or 0
    local btns = {}

    local clos = {
        OnChange = function() end
    }

    setmetatable(clos, {
        __index = function(_, k)
            if k == "Value" then
                return value
            else
                return group[k]
            end
        end,
        __newindex = function(_, k, v)
            if k == "Value" then
                value = v
                for i, option in ipairs(options) do
                    local radio = btns[i]
                    if radio then
                        radio.Active = (value & option.Value) ~= 0
                    end
                end
            elseif k == "WrapPos" then
                for i, radio in ipairs(btns) do
                    radio.SameLine = (i > 1 and i % v ~= 1)
                end
            else
                group[k] = v
            end
        end
    })

    local uuid = RBUtils.Uuid_v4()
    for i, option in ipairs(options) do
        local radio = group:AddRadioButton(option.Label or ("Option" .. i))
        radio.IDContext = "BitmaskRadioButton__" .. option.Label .. "__" .. i .. "__" .. uuid
        radio.Active = initValue and (initValue & option.Value) ~= 0 or false
        radio.OnChange = function(r)
            r.Active = not r.Active
            if r.Active then
                value = value | option.Value
            else
                value = value & (~option.Value)
            end
            if clos.OnChange then
                clos.OnChange(r, value)
            end
        end

        --radio.SameLine = (i > 1 and i % 4 ~= 1)
        btns[i] = radio
    end

    return clos
end

--- @param parent ExtuiTreeParent
--- @param options RadioButtonOption[]
--- @param initValue number
--- @return EnumRadioButtonsGroup
function ImguiElements.AddEnumRadioButtons(parent, options, initValue)
    local group = parent:AddGroup("EnumRadioButtonsGroup" .. RBUtils.Uuid_v4())

    local current = initValue
    local radioButtons = {}
    local closure = {
        OnChange = function() end
    }

    setmetatable(closure, {
        __index = function(_, k)
            if k == "Value" then
                return current
            end
            return group[k]
        end,
        __newindex = function(_, k, v)
            if k == "Value" then
                current = v
                for enumName, radio in pairs(radioButtons) do
                    local enumValue = radio.UserData.EnumValue
                    radio.Active = (current == enumValue)
                end
                return
            elseif k == "WrapPos" then
                for i, radio in ipairs(radioButtons) do
                    radio.SameLine = (i > 1 and i % v ~= 1)
                end
                return
            end
            group[k] = v
        end
    })


    for i, option in ipairs(options) do
        local enumName = option.Label
        local enumValue = option.Value
        local radio = group:AddRadioButton(enumName .. "##_Setter")
        radioButtons[enumName] = radio
        radio.Active = (initValue == enumValue)
        radio.UserData = {
            EnumValue = enumValue
        }
        if option.Tooltip then
            radio.OnHoverEnter = function(r)
                r:Tooltip():AddText(tostring(option.Tooltip))
                r.OnHoverEnter = nil
            end
        end
        radio.OnChange = function(r)
            if current == enumValue then
                return
            end
            current = enumValue
            for _, otherRadio in pairs(radioButtons) do
                if otherRadio ~= r then
                    otherRadio.Active = false
                end
            end
            r.Active = true
            closure.OnChange(r, current)
        end
        --radio.SameLine = i > 1 and i % 4 ~= 1
    end

    return closure
end