STYLEMENU_WIDTH = 1000
STYLEMENU_HEIGHT = 1200

--- @class StyleMenu
--- @field panel ExtuiWindow|ExtuiTabItem
StyleMenu = _Class("StyleMenu")

function StyleMenu:__init(parent)
    self.panel = nil
    self.parent = parent
    self.isValid = true
    self.isAttach = true
    self.isWindow = false
    self.saveFuncs = {}
end

function StyleMenu:Render()

    if self.isAttach and self.parent then
        self.panel = self.parent:AddTabItem(GetLoca("Style"))
        self.isWindow = false
    else
        self.panel = WindowManager.RegisterWindow("generic", GetLoca("Style"), "Menu", self, {STYLEMENU_WIDTH, STYLEMENU_HEIGHT})
        self.isWindow = true
    end

    --self:RenderPreviewWindow()

    self:RenderSaveLoad()

    self:RenderColorPickers()

    self:RenderStyleSliders()
end

function StyleMenu:Add(parent)
    local styleMenu = StyleMenu.new(parent)
    styleMenu:Render()
    return styleMenu
end


function StyleMenu:RenderSaveLoad()
    local tbl = self.panel:AddTable("StyleSaveLoad", 2)
    local row = tbl:AddRow()
    local leftCell = row:AddCell()
    local rightCell = row:AddCell()
    tbl.ColumnDefs[1] = {WidthStretch = true}
    tbl.ColumnDefs[2] = {WidthFixed = true}

    local saveConfigButton = leftCell:AddButton(GetLoca("Save"))
    local loadConfigButton = leftCell:AddButton(GetLoca("Load"))

    loadConfigButton.SameLine = true

    saveConfigButton.OnClick = function()
        for name, func in pairs(self.saveFuncs) do
            func()
        end
        UIConfig.SaveConfig("Theme")
    end

    loadConfigButton.OnClick = function()
        UIConfig.LoadConfig()
        if self.reloadColors then
            self.reloadColors()
        end
        if self.reloadStyleVars then
            self.reloadStyleVars()
        end
    end

    local detachButton = rightCell:AddButton(self.isWindow and GetLoca("Attach") or GetLoca("Detach"))
    
    detachButton.OnClick = function()
        self.saveFuncs = {}
        self.isAttach = not self.isAttach
        if self.isWindow then
            WindowManager.DeleteWindow(self.panel)
            self.panel = nil
        else
            self.panel:Destroy()
            self.panel = nil
        end
        self:Render()
    end
end

function StyleMenu:RenderColorPickers()
    local colorAutoReload = self.panel:AddCheckbox(GetLoca("Auto Reload"), UICONFIG.Theme.Color.autoReload or false)
    colorAutoReload.IDContext = "ColorAutoReload"

    colorAutoReload.OnChange = function(c)
        UICONFIG.Theme.Color.autoReload = c.Checked
        UIConfig.SaveConfig("Theme")
    end

    local accentColorPicker = self.panel:AddColorEdit(GetLoca("Accent Color"))
    accentColorPicker.Color = UICONFIG.Theme.Color.Accent or {0.2, 0.2, 0.2, 0.85}

    local themeAlphaSlider = self.panel:AddSlider(GetLoca("Accent Alpha"), 1, 0, 1)
    themeAlphaSlider.Value = {accentColorPicker.Color[4] or 1, 0, 0, 0}

    themeAlphaSlider.OnChange = function(s)
        local pickerColor = accentColorPicker.Color
        accentColorPicker.Color = {pickerColor[1], pickerColor[2], pickerColor[3], s.Value[1]}
        accentColorPicker.OnChange()
    end

    local secondaryColorPicker = self.panel:AddColorEdit(GetLoca("Secondary Accent Color"))
    secondaryColorPicker.Color = UICONFIG.Theme.Color.Accent2 or {0.3, 0.3, 0.3, 0.85}
    secondaryColorPicker.OnChange = function(c)
        local color = secondaryColorPicker.Color
        UICONFIG.Theme.Color.Accent2 = color
        accentColorPicker.OnChange()
    end

    local bgColorPicker = self.panel:AddColorEdit(GetLoca("Background Color"))
    bgColorPicker.Color = UICONFIG.Theme.Color.MainBackground or {0.1, 0.1, 0.1, 0.85}

    local bgAlphaSlider = self.panel:AddSlider(GetLoca("Bg Alpha"), 1, 0, 1)
    bgAlphaSlider.Value = {bgColorPicker.Color[4] or 1, 0, 0, 0}

    bgAlphaSlider.OnChange = function(s)
        local pickerColor = bgColorPicker.Color
        bgColorPicker.Color = {pickerColor[1], pickerColor[2], pickerColor[3], s.Value[1]}
        bgColorPicker.OnChange()
    end

    local colorsHeader = ImguiElements.AddTree(self.panel, GetLoca("Colors"))
    colorsHeader.Framed = true

    local colorPickers = {}

    local colorTrees = {}

    --- @type GuiColorCategories[]
    local colorOrder = {
        "Color.Text",
        "Color.Background",
        "Color.Border",
        "Color.Table",
        "Color.Button",
        "Color.Frame",
        "Color.Slider",
        "Color.Window",
        "Color.Nav",
        "Color.Tab",
        "Color.Separator",
        "Color.Plot",
        "Color.Other"
    }

    local colorOrderMap = {}
    for i, v in ipairs(colorOrder) do
        colorOrderMap[v] = i
    end

    local colorsMap = GetAllGuiColorNames()
    local colorsArray = RBTableUtils.MapToSortedArrayByFunc(colorsMap, function(a, b)
        local aIndex = colorOrderMap[a.Value] or (#colorOrder + 1)
        local bIndex = colorOrderMap[b.Value] or (#colorOrder + 1)
        if aIndex == bIndex then
            return a.Key < b.Key
        end
        return aIndex < bIndex
    end)

    for _,obj in ipairs(colorsArray) do
        local category = obj.Value
        if not colorTrees[category] then
            colorTrees[category] = ImguiElements.AddTree(colorsHeader, category)
        end
    end

    for _,obj in ipairs(colorsArray) do
        local name = obj.Key
        local category = obj.Value
        local colorsTree = colorTrees[category]
        local colorPicker = colorsTree:AddColorEdit(name)
        colorPicker.UserData = { Changed = false }
        colorPicker.Color = UICONFIG.Theme.Color[name] or {1, 1, 1, 1}
        colorPicker.OnChange = function(c)
            c = colorPicker
            WindowManager.SetAllWindowsColor(name, c.Color)
            c.UserData.Changed = true
        end
        self.saveFuncs[name] = function()
            if not colorPicker.UserData.Changed then return end
            --- @diagnostic disable-next-line
            UICONFIG.Theme.Color[name] = colorPicker.Color
        end
        colorPickers[name] = colorPicker
    end

    accentColorPicker.OnChange = function(c)
        local themeColor = accentColorPicker.Color
        local accent2Color = secondaryColorPicker.Color
        local bgColor = bgColorPicker.Color
        local generatedColors = ThemeHelpers.GenerateTheme(themeColor, accent2Color, bgColor) 
        for colorName, colorValue in pairs(generatedColors) do
            colorValue = {colorValue[1], colorValue[2], colorValue[3], colorValue[4] or c.Color[4]}
            local p = colorPickers[colorName]
            p.Color = colorValue
            p.OnChange()
        end
        themeAlphaSlider.Value = {themeColor[4] or 1, 0, 0, 0}
        self.saveFuncs.LOPMainColor = function()
            UICONFIG.Theme.Color.Accent = themeColor
            UICONFIG.Theme.Color.MainBackground = bgColor
        end
    end

    bgColorPicker.OnChange = function()
        accentColorPicker.OnChange()
        bgAlphaSlider.Value = {bgColorPicker.Color[4] or 1, 0, 0, 0}
    end

    self.reloadColors = function ()
        accentColorPicker.Color = UICONFIG.Theme.Color.Accent or {0.2, 0.2, 0.2, 0.85}
        themeAlphaSlider.Value = {accentColorPicker.Color[4] or 1, 0, 0, 0}
        bgColorPicker.Color = UICONFIG.Theme.Color.MainBackground or {0.1, 0.1, 0.1, 0.85}
        bgAlphaSlider.Value = {bgColorPicker.Color[4] or 1, 0, 0, 0}
        for name, value in pairs(UICONFIG.Theme.Color) do
            if name == "MainBackground" or name == "MainTheme" or name == "autoReload" then
                goto continue
            end
            if not colorPickers[name] then
                goto continue
            end
            colorPickers[name].Color = UICONFIG.Theme.Color[name] or {1, 1, 1, 1}
            colorPickers[name].OnChange()
            ::continue::
        end
    end

    if UICONFIG.Theme.Color.autoReload then
        self.reloadColors()
    end
end

function StyleMenu:RenderStyleSliders()
    local styleAutoReload = self.panel:AddCheckbox(GetLoca("Auto Reload"), UICONFIG.Theme.Style.autoReload or false)
    styleAutoReload.IDContext = "StyleAutoReload"

    styleAutoReload.OnChange = function(c)
        UICONFIG.Theme.Style.autoReload = c.Checked
        UIConfig.SaveConfig("Theme")
    end

    local baseRoundingSlider = self.panel:AddSlider(GetLoca("Base Rounding"), UICONFIG.Theme.Style.BaseRounding or 5, 0, 40)
    local basePaddingSlider = self.panel:AddSlider(GetLoca("Base Padding"), UICONFIG.Theme.Style.BasePadding or 10, 0, 20)
    local baseBorderSlider = self.panel:AddSlider(GetLoca("Base Border"), UICONFIG.Theme.Style.BaseBorder, 0, 5)
    basePaddingSlider.Visible = false

    local styleVarHeader = ImguiElements.AddTree(self.panel, GetLoca("Style Variables"))
    styleVarHeader.Framed = true

    local styleVarSlider = {}

    local styleVarTrees = {}

    --- @type GuiStyleVarCategories[]
    local styleVarOrder = {
        "Var.Global",
        "Var.Window",
        "Var.Child",
        "Var.Popup",
        "Var.Frame",
        "Var.Scrollbar",
        "Var.Tab",
        "Var.Separator",
        "Var.Layout",
        "Var.Align",
        "Var.Table",
        "Var.Other"
    }

    local styleVarSliderClamp = {
        Rounding = {0, 40},
        Padding = {0, 20},
        BorderSize = {0, 5},
        Spacing = {0, 20},
        Align = {0, 1},
        MinSize = {0, 100},
        Alpha = {0.5, 1},
        Size = {1, 20}
    }

    local styleVarOrderMap = {}
    for i, v in ipairs(styleVarOrder) do
        styleVarOrderMap[v] = i
    end

    local varsMap = GetAllGuiStyleVarNames()
    local varsArray = RBTableUtils.MapToSortedArrayByFunc(varsMap, function(a, b)
        local aIndex = styleVarOrderMap[a.Value] or (#styleVarOrder + 1)
        local bIndex = styleVarOrderMap[b.Value] or (#styleVarOrder + 1)
        if aIndex == bIndex then
            return a.Key < b.Key
        end
        return aIndex < bIndex
    end)

    local function GetStyleVarType(name)
        local vec2_keywords = {
            "Padding",
            "Spacing",
            "Align",
            "MinSize"
        }

        local float_keywords = {
            "Alpha",
            "Rounding",
            "Size",
            "Border"
        }

        for _, key in ipairs(vec2_keywords) do
            if name:find(key) then
                return 2, key
            end
        end

        for _, key in ipairs(float_keywords) do
            if name:find(key) then
                return 1, key
            end
        end

        return 1
    end
    
    for _,obj in ipairs(varsArray) do
        local category = obj.Value
        if not styleVarTrees[category] then
            styleVarTrees[category] = ImguiElements.AddTree(styleVarHeader, category)
        end
    end

    for _,obj in ipairs(varsArray) do
        local name = obj.Key
        local category = obj.Value
        local styleVarTree = styleVarTrees[category]
        local min = 0
        local max = 1
        local componentsCnt, componentType = GetStyleVarType(name)
        if styleVarSliderClamp[componentType] then
            min = styleVarSliderClamp[componentType][1]
            max = styleVarSliderClamp[componentType][2]
        end
        local slider = styleVarTree:AddSlider(name, 1, min, max)
        slider.UserData = { Changed = false }
        if UICONFIG.Theme.Style[name] then
            slider.Value = { UICONFIG.Theme.Style[name][1] or 1, UICONFIG.Theme.Style[name][2] or 0, 0, 0 }
        else
            slider.Value = { 1, 0, 0, 0 }
        end
        
        slider.Components = componentsCnt
        slider.OnChange = function(s)
            s = slider
            WindowManager.SetAllWindowsStyle(name, s.Value[1], s.Value[2])
            s.UserData.Changed = true
        end
        self.saveFuncs[name] = function()
            if not slider.UserData.Changed then return end
            --- @diagnostic disable-next-line
            UICONFIG.Theme.Style[name] = {slider.Value[1], slider.Value[2] or 0}
        end
        styleVarSlider[name] = slider
    end

    baseRoundingSlider.OnChange = function()
        local baseRounding = baseRoundingSlider.Value[1]
        local basePadding = basePaddingSlider.Value[1]
        local baseBorder = baseBorderSlider.Value[1]
        local styleVars = ThemeHelpers.GenerateUIStyle(baseRounding, basePadding, baseBorder)
        for name, value in pairs(styleVars) do
            local param1 = nil
            local param2 = nil
            if type(value) == "table" then
                param1 = value[1]
                param2 = value[2]
            else
                param1 = value
            end
            local s = styleVarSlider[name]
            s.Value = {param1, param2 or 0, 0, 0}
            s.OnChange()
        end
        UICONFIG.Theme.Style.BaseRounding = baseRounding
        UICONFIG.Theme.Style.BasePadding = basePadding
        UICONFIG.Theme.Style.BaseBorder = baseBorder
    end
    basePaddingSlider.OnChange = baseRoundingSlider.OnChange
    baseBorderSlider.OnChange = baseRoundingSlider.OnChange

    self.reloadStyleVars = function ()
        baseBorderSlider.Value = {UICONFIG.Theme.Style.BaseBorder or 0, 0, 0, 0}
        basePaddingSlider.Value = {UICONFIG.Theme.Style.BasePadding or 10, 0, 0, 0}
        baseRoundingSlider.Value = {UICONFIG.Theme.Style.BaseRounding or 5, 0, 0, 0}
        for name,value in pairs(UICONFIG.Theme.Style) do
            if name == "BaseRounding" or name == "BasePadding" or name == "BaseBorder" or name == "autoReload" then
                goto continue
            end
            local slider = styleVarSlider[name]
            if UICONFIG.Theme.Style[name] then
                slider.Value = { UICONFIG.Theme.Style[name][1] or 1, UICONFIG.Theme.Style[name][2] or 0, 0, 0 }
                slider.OnChange()
            end    
            ::continue::
        end
    end

    if UICONFIG.Theme.Style.autoReload then
        self.reloadStyleVars()
    end
end
