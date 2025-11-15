--- @class RB_ContextItem
--- @field Label string
--- @field OnClick fun(selectable: ExtuiSelectable)
--- @field Hint string?
--- @field Icon string?
--- @field HotKey Keybinding
--- @field Separator boolean?
--- @field DontClosePopups boolean?

--- @class RB_ContextMenu : ExtuiTable
--- @field AddItem fun(self: RB_ContextMenu, label: string, onClick: fun(selectable: ExtuiSelectable), hint:string?, image?:string): ExtuiSelectable
--- @field AddSeparator fun(self: RB_ContextMenu)
--- @field AddItemPacked fun(self: RB_ContextMenu, item: RB_ContextItem): ExtuiSelectable
--- @field AddMenu fun(self: RB_ContextMenu, label: string): RB_ContextMenu
--- @field AddContext fun(self: RB_ContextMenu, context: RB_ContextItem[], isFocus: fun(): boolean)
local ContextMenuClass = {}

function ContextMenuClass:AddItem(label, onClick, hint, image)
    local tab = self.tab
    local row = tab:AddRow() --[[@as ExtuiTableRow]]
    local imageCell = row:AddCell()
    if image and image ~= "" then
        local img = imageCell:AddImage(image)
        img.ImageData.Size = ToVec2(36 * SCALE_FACTOR)
        tab.BordersInnerV = true
    end
    local innerCell = row:AddCell()
    local innerTable = innerCell:AddTable("InnerTable##" .. Uuid_v4(), 3) --[[@as ExtuiTable]]
    innerTable.ColumnDefs[1] = { WidthStretch = true }
    innerTable.ColumnDefs[2] = { WidthFixed = true , Width = 80 * SCALE_FACTOR }
    innerTable.ColumnDefs[3] = { WidthFixed = true }
    local innerRow = innerTable:AddRow() --[[@as ExtuiTableRow]]
    local cell = innerRow:AddCell()
    local spacer = innerRow:AddCell()
    local hintCell = innerRow:AddCell()

    if hint and hint ~= "" then
        local hintLabel = hintCell:AddText(hint)
        hintLabel.Font = "Medium"
        hintLabel:SetStyle("Alpha", 0.6)
        hintLabel:SetColor("Text", HexToRGBA("FFAAAAAA"))
    end

    local selectable = cell:AddSelectable(label) --[[@as ExtuiSelectable]]
    selectable.Font = "Medium"
    selectable.SpanAllColumns = true
    selectable.OnClick = function(s)
        s.Selected = false
        if onClick then
            onClick(s)
        end
    end
    return selectable
end

function ContextMenuClass:AddSeparator()
    local tab = self.tab
    local sepRow = tab:AddRow() --[[@as ExtuiTableRow]]
    local sepCells = {sepRow:AddCell(), sepRow:AddCell()}
    for _, cell in ipairs(sepCells) do
        cell:AddSeparator()
    end
end

function ContextMenuClass:AddItemPacked(item)
    return self:AddItem(item.Label, item.OnClick, item.Hint, item.Icon)
end

function ContextMenuClass:AddMenu(label)
    local tab = self.tab
    local row = tab:AddRow()
    local cell = row:AddCell()
    local menu = cell:AddMenu(label)
    return StyleHelpers.AddContextMenu(menu)
end

function ContextMenuClass:AddContext(context, isFocus)
    for _, item in ipairs(context) do
        if item.Separator then
            self:AddSeparator()
            goto continue
        end

        local selectable = self:AddItem(item.Label, item.OnClick, item.Hint, item.Icon)
        if item.Danger then
            ApplyDangerSelectableStyle(selectable)
        end
        if item.DontClosePopups then
            selectable.DontClosePopups = true
        end

        if item.HotKey and not self.hotKeySubs[item.Label] then
            self.hotKeySubs[item.Label] = SubscribeKeyAndMouse(function (e)
                local ok, focus = pcall(function()
                    return isFocus()
                end)
                if not ok then return UNSUBSCRIBE_SYMBOL end
                if not focus then return end
                if not e.Pressed then return end

                item.OnClick(selectable)
            end, item.HotKey)
        end
        ::continue::
    end
end

---@param parent ExtuiTreeParent
---@param title string?
---@return RB_ContextMenu
function StyleHelpers.AddContextMenu(parent, title)
    local group = parent:AddGroup("ContextMenuGroup##" .. (title or Uuid_v4())) --[[@as ExtuiGroup]]
    if title and title ~= "" then
        local titleText = group:AddText(title)
        titleText.Font = "Medium"
        titleText:SetStyle("Alpha", 0.8)
        titleText:SetColor("Text", HexToRGBA("FFAAAAAA"))
        group:AddSeparator()
    end
    local tab = group:AddTable("SelectionTable##" .. Uuid_v4(), 2) --[[@as ExtuiTable]]
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { WidthStretch = true }

    local hotKeySubs = {}
    --- @type RB_ContextMenu
    local instance = {
        tab = tab,
        group = group,
        hotKeySubs = hotKeySubs,
    }

    local keyToSetOnGroup = {
        SameLine = true,
        Visible = true,
        Destroy = true,
    }

    setmetatable(instance, {
        __index = function(t, k)
            if ContextMenuClass[k] then
                return ContextMenuClass[k]
            end
            if keyToSetOnGroup[k] then
                return group[k]
            end
            return tab[k]
        end,
        __newindex = function(t, k, v)
            if keyToSetOnGroup[k] then
                group[k] = v
                return
            end
            tab[k] = v
        end
    })

    return instance
end