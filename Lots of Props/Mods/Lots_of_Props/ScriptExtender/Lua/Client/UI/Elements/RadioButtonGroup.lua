--- @class RadioButtonConfig
--- @field Label string
--- @field Field string
--- @field TrueValue any
--- @field FalseValue any
--- @field Disabled boolean
--- @field Tooltip string

local function NormalizeRadioButtonConfigs(config)
    if not config.Field or config.Field == "" then
        Warning("RadioButtonConfig missing Field")
        return nil
    end

    if config.TrueValue == nil then
        config.TrueValue = true
    end

    if config.FalseValue == nil then
        config.FalseValue = false
    end
    
    if not config.Label or config.Label == "" then
        config.Label = tostring(config.Field)
    end

    return config
end

--- @class RadioButtonGroup
--- @field Buttons table<string, ExtuiRadioButton>
--- @field DeactiveAll fun()
--- @field DisableButton fun(field: string)
--- @field EnableButton fun(field: string)
--- @field SetActive fun(field: string)
--- @field GetActive fun(): string|nil
--- @field SetTooltip fun(field: string, text: string)
--- @field SetState fun(field: string, disabled: boolean)
--- @field Destroy fun()

--- @param parent ExtuiTreeParent
--- @param configs RadioButtonConfig[]
--- @param obj table
--- @param onChange fun(field: string, value: any)|nil
--- @return RadioButtonGroup
function AddRadioButtonGroup(parent, configs, obj, onChange)
    for i = #configs, 1, -1 do
        local config = configs[i]
        local normalized = NormalizeRadioButtonConfigs(config)
        if not normalized then
            table.remove(configs, i)
        else
            configs[i] = normalized
        end
    end

    local btns = {}
    local tooltips = {}

    local function deactiveAll()
        for field, btn in pairs(btns) do
            if btn and btn.Active then
                btn.Active = false
                if obj then
                    obj[field] = btn.UserData and btn.UserData.Config and btn.UserData.Config.FalseValue
                end
            end
        end
    end

    local function showTooltip(btn, text)
        if not text or text == "" then return end
        local field = btn.UserData and btn.UserData.Field
        if not field then return end
        if tooltips[field] then return end
        
        tooltips[field] = btn:Tooltip():AddText(text)
        btn:Tooltip():SetStyle("Alpha", 1)
    end

    local function hideTooltip(btn)
        local field = btn.UserData and btn.UserData.Field
        if not field then return end
        if not tooltips[field] then return end
        
        tooltips[field]:Destroy()
        tooltips[field] = nil
        btn:Tooltip():SetStyle("Alpha", 0)
    end

    for i, config in ipairs(configs) do
        local field = config.Field
        local isSelected = config.Selected or (obj and obj[field] == config.TrueValue)
        
        local btn = parent:AddRadioButton(config.Label, isSelected)
        btn.IDContext = field .. "_RadioButton"
        btn.UserData = { 
            Config = config, 
            Object = obj, 
            Field = field 
        }

        if i > 1 then
            btn.SameLine = true
        end
    
        btn.Active = isSelected
        btn.Disabled = config.Disabled == true
    
        if btn.Disabled then
            DisableAndSetAlpha(btn)
            if config.Tooltip then
                showTooltip(btn, config.Tooltip)
            end
        else
            if config.Tooltip then
                btn:Tooltip():AddText(config.Tooltip)
            end
        end
        
        btn.OnChange = function(button)
            if button.Disabled then return end
            
            deactiveAll()
            button.Active = true
            
            if obj then
                obj[field] = config.TrueValue
            end
            
            if onChange then
                onChange(field, config.TrueValue)
            end
        end
        
        btns[field] = btn
    end

    local radioButtonGroup
    radioButtonGroup = {
        Buttons = btns,
        
        DeactiveAll = deactiveAll,
        
        DisableButton = function(field)
            local btn = btns[field]
            if btn then
                DisableAndSetAlpha(btn)
                
                local config = btn.UserData and btn.UserData.Config
                if config and config.Tooltip then
                    showTooltip(btn, config.Tooltip)
                end
            end
        end,
        
        EnableButton = function(field)
            local btn = btns[field]
            if btn then
                btn.Disabled = false
                EnableAndSetAlpha(btn)
                hideTooltip(btn)
            end
        end,
        
        SetActive = function(field)
            deactiveAll()
            local btn = btns[field]
            if btn and not btn.Disabled then
                btn.Active = true
                local config = btn.UserData and btn.UserData.Config
                if obj and config then
                    obj[field] = config.TrueValue
                end
                if onChange then
                    onChange(field, config and config.TrueValue)
                end
            end
        end,
        
        GetActive = function()
            for field, btn in pairs(btns) do
                if btn.Active then
                    return field
                end
            end
            return nil
        end,
        
        SetTooltip = function(field, text)
            local btn = btns[field]
            if btn then
                hideTooltip(btn)
                if text and text ~= "" then
                    showTooltip(btn, text)
                end
            end
        end,
        
        Destroy = function()
            for field, btn in pairs(btns) do
                if btn then
                    hideTooltip(btn)
                    btn:Destroy()
                end
            end
            btns = {}
            tooltips = {}
        end,

        SetState = function(field, disabled)
            if disabled then
                radioButtonGroup.DisableButton(field)
            else
                radioButtonGroup.EnableButton(field)
            end
        end
    }

    return radioButtonGroup 
end