--- @class CCAVBrowser : RootTemplateBrowser
--- @field new fun(manager:CCAVManager, displayName:string):CCAVBrowser
CCAVBrowser = _Class("CCAVBrowser", IconBrowser)

local function addVisual(ccavId, target)
    NetChannel.CallOsiris:SendToServer({
        Function = "AddCustomVisualOverride",
        Args = {
            target,
            ccavId
        }
    })
end

local function removeVisual(ccavId, target)
    NetChannel.CallOsiris:SendToServer({
        Function = "RemoveCustomVisualOvirride",
        Args = {
            target,
            ccavId
        }
    })
end

--- @type table<string, table<string, boolean>> -- [targetGuid] = { [ccavId] = true }
local originVisuals = {}
--- @param target string
local function recordVisuals(target)
    local ent = Ext.Entity.Get(target)
    if not ent or not ent.CharacterCreationAppearance then return end

    originVisuals[target] = {}
    for _, visual in pairs(ent.CharacterCreationAppearance.Visuals) do
        originVisuals[target][visual] = true
    end
end

--- @param target string
--- @param visualId string
--- @return boolean
local function hasVisual(target, visualId)
    if not originVisuals[target] then return false end
    return originVisuals[target][visualId] == true
end

function CCAVBrowser:SubclassInit()
    RootTemplateBrowser.SubclassInit(self)
    self.selectedFields = { ["DisplayName"] = true }
    self.iconTooltipName = "DisplayName"
    self.tooltipNameOptions = { "DisplayName", "Uuid"}
end

function CCAVBrowser:OnSelectChange(guid)
    self.dataManager:CreateDynamicTags(guid)
    if EntityHelpers.IsPartyMember(guid) then
        recordVisuals(guid)
    end
    self:RefreshTagFilter()
end

function CCAVBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[Browser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field. Browser: " .. tostring(self.displayName))
        return nil
    end
    local popup = nil
    local rPopup = nil

    local iconImage = nil
    local disName = entry[self.iconTooltipName]
    if not disName or disName == "" then
        disName = "Unknown"
    end
    local button = cell:AddButton(disName .. "##" ..entry.Uuid)
    button:SetColor("Button", self.iconButtonBgColor or ColorUtils.HexToRGBA("FF615238"))
    iconImage = button

    iconImage.OnClick = function()
        if not popup then
            popup = cell:AddPopup("Root Template Details")
            popup.IDContext = entry.Uuid .. "Popup" .. RBUtils.Uuid_v4()
            local attrs = {
                Uuid = entry.Uuid,
                VisualName = entry.VisualName
            }
            ImguiElements.AddReadOnlyAttrTable(popup, attrs)
        end
        popup:Open()
    end

    iconImage.OnRightClick = function()
        if not rPopup then
            rPopup = cell:AddPopup("Preview Template")
            rPopup.IDContext = entry.Uuid .. "RPopup" .. RBUtils.Uuid_v4()
            self:RenderCustomizationTab(rPopup, entry)
            local actTab = ImguiElements.AddContextMenu(rPopup, "Actions")
            actTab:AddItem("Add Custom Visual Override", function()
                local target = self:GetSelected()
                addVisual(entry.Uuid, target) 
                Ext.Timer.WaitForRealtime(100, function()
                    recordVisuals(target) -- record so won't be removed on hover leave
                end)
            end)

            actTab:AddItem("Remove Custom Visual Override", function()
                local target = self:GetSelected()
                removeVisual(entry.Uuid, target)
                Ext.Timer.WaitForRealtime(100, function()
                    recordVisuals(target)
                end)
            end)
        end
        rPopup:Open()
    end

    iconImage.OnHoverEnter = function()
        local selected = self:GetSelected()
        if not originVisuals[selected] then
            recordVisuals(selected)
        end
        if hasVisual(selected, entry.Uuid) then return end
        addVisual(entry.Uuid, selected) -- temp preview
    end

    iconImage.OnHoverLeave = function()
        local selected = self:GetSelected()
        if not hasVisual(selected, entry.Uuid) then
            removeVisual(entry.Uuid, selected)
        end
    end

    iconImage:Tooltip():AddText(entry[self.iconTooltipName] or "Unknown")

    return iconImage
end
