SCALE_FACTOR = 1.0

UIHelpers = UIHelpers or {}

---@return integer width
---@return integer height
function UIHelpers.GetScreenSize()
    local screen = Ext.IMGUI.GetViewportSize()
    return screen[1], screen[2]
end

function UIHelpers.GetUIScale()
    local _, screenHeight = UIHelpers.GetScreenSize()
    local baseHeight = 2160
    return screenHeight / baseHeight
end

SCALE_FACTOR = UIHelpers.GetUIScale()

IMAGESIZE = {
    ROW = Vec2.new(36, 36) * SCALE_FACTOR,
    TINY = Vec2.new(32, 32) * SCALE_FACTOR,
    FRAME = Vec2.new(42, 42) * SCALE_FACTOR,
    SMALL = Vec2.new(42, 42) * SCALE_FACTOR,
    MEDIUM = Vec2.new(64, 64) * SCALE_FACTOR,
    LARGE = Vec2.new(128, 128) * SCALE_FACTOR,
}

UIConfig = {}
RBUICONFIG = {
    Theme = {
        Color = {
            autoReload = false,
        },
        Style = {
            autoReload = false,
        }
    },
    EffectMenu = {
        AutoSave = true,
    },
    DEBUG_LEVEL = 4
}

function UIConfig.SaveConfig(field)
    if field then
        UIConfig.SaveConfigField(field)
        return
    end

    local configData = Ext.Json.Stringify(RBUICONFIG)
    local filePath = FilePath.GetUIConfigPath()
    Ext.IO.SaveFile(filePath, configData)
end

function UIConfig.LoadConfig()
    local filePath = FilePath.GetUIConfigPath()
    local configData = Ext.IO.LoadFile(filePath)
    if configData then
        local saved = Ext.Json.Parse(configData)
        for key, v in pairs(saved) do
            RBUICONFIG[key] = v
        end
    end

    SetDebugLevel(RBUICONFIG.DEBUG_LEVEL or 4)
end

function UIConfig.SaveConfigField(field)
    local filePath = FilePath.GetUIConfigPath()
    local raw = Ext.IO.LoadFile(filePath)
    local data = raw and Ext.Json.Parse(raw) or {}

    data[field] = RBUICONFIG[field]
    local configData = Ext.Json.Stringify(data)
    Ext.IO.SaveFile(filePath, configData)
end

UIConfig.LoadConfig()


