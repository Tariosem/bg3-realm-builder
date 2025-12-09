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

function CCAVBrowser:SubclassInit()
    RootTemplateBrowser.SubclassInit(self)
    self.selectedFields = { ["DisplayName"] = true }
    self.iconTooltipName = "DisplayName"
    self.tooltipNameOptions = { "DisplayName", "Uuid"}
end

function CCAVBrowser:OnSelectChange(guid)
    self.dataManager:CreateDynamicTags(guid)
    self:AddTagsFilter()
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
    button:SetColor("Button", self.iconButtonBgColor or HexToRGBA("FF615238"))
    iconImage = button

    iconImage.OnClick = function()
        if not popup then
            popup = cell:AddPopup("Root Template Details")
            popup.IDContext = entry.Uuid .. "Popup" .. Uuid_v4()
            local attrs = {
                Uuid = entry.Uuid,
                TemplateName = entry.TemplateName,
                Icon = entry.Icon,
                TemplateId = entry.TemplateId,
                SourceFile = entry.SourceFile,
                Path = entry.Path,
            }
            ImguiElements.AddReadOnlyAttrTable(popup, attrs)
        end
        popup:Open()
    end

    iconImage.OnRightClick = function()
        if not rPopup then
            rPopup = cell:AddPopup("Preview Template")
            rPopup.IDContext = entry.Uuid .. "RPopup" .. Uuid_v4()
            self:RenderCustomizationTab(rPopup, entry)
            local actTab = ImguiElements.AddContextMenu(rPopup, "Actions")
            actTab:AddItem("Add Custom Visual Override", function()
                local target = self:GetSelected()
                addVisual(entry.Uuid, target)
                HistoryManager:PushCommand({
                    Name = "Add Custom Visual Override",
                    Undo = function ()
                        removeVisual(entry.Uuid, target)
                    end,
                    Redo = function ()
                        addVisual(entry.Uuid, target)
                    end
                })
            end)

            actTab:AddItem("Remove Custom Visual Override", function()
                local target = self:GetSelected()
                NetChannel.VisualOverride:RequestToServer({
                    Function = "RemoveCustomVisualOvirride",
                    Args = {
                        target,
                        entry.Uuid
                    }
                }, function (response)
                    
                end)
                HistoryManager:PushCommand({
                    Name = "Remove Custom Visual Override",
                    Undo = function ()
                        addVisual(entry.Uuid, target)
                    end,
                    Redo = function ()
                        removeVisual(entry.Uuid, target)
                    end
                })
            end)
        end
        rPopup:Open()
    end

    iconImage:Tooltip():AddText(entry[self.iconTooltipName] or "Unknown")

    return iconImage
end