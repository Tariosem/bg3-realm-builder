local isPreviewing = false
local previewObject = nil
local notif = Notification.new("Is Previewing Item...")
notif.Pivot = { 0.5, 0 }
notif.AutoFadeOut = false

PlacementPreview = {}

--- @param entry {Uuid:string}
function PlacementPreview:BeginPlacementPreview(entry, entryDisplayName)
    if SpawnInspector.IsSpawning() then
        local WarningNotif = Notification.new("Cannot preview item while spawning is in progress.")
        WarningNotif.Pivot = { 0.5, 0 }
        WarningNotif.Duration = 3000
        WarningNotif:Show("Placement Preview Warning", function (panel)
            StyleHelpers.ApplyWarningTooltipStyle(panel)
            panel:AddText("Cannot preview placement while spawning is in progress.")
        end)
        Warning("[IconBrowser] Cannot preview item while spawning is in progress.")
        return
    end
    IsPreviewing = true


    notif:Show("Placement Preview", function(panel)
        local midAlighTab = panel:AddTable("Midddd", 3)
        midAlighTab.ColumnDefs[1] = { WidthStretch = true }
        midAlighTab.ColumnDefs[2] = { WidthFixed = true }
        midAlighTab.ColumnDefs[3] = { WidthStretch = true }
        local row = midAlighTab:AddRow()
        local midCell = ({row:AddCell(), row:AddCell(), row:AddCell()})[2]
        local icon = RBCheckIcon(entry.Icon or RB_ICONS.Box)
        local image = nil
        if icon == RB_ICONS.Box then
        else
            image = midCell:AddImage(icon, RBUtils.ToVec2(64 * SCALE_FACTOR))
        end
        local displayName = entryDisplayName or entry.DisplayName or entry.TemplateName or "Unknown"
        midCell:AddText(displayName).SameLine = image and true or false

        panel:AddText(GetLoca("Left click to spawn the template at the previewed location."))
        panel:AddText(GetLoca("Scroll mouse wheel to rotate the item."))
        local caution = panel:AddText(GetLoca("Press [ESCAPE] or [BACKSPACE] to cancel the preview."))
        caution:SetColor("Text", ColorUtils.HexToRGBA("FFFFFFFF"))
        caution.Font = "Large"
    end)
    
    previewObject = nil
    local mouseButtonSub = nil
    local mouseWheelSub = nil
    local stickTimer = nil
    local cancelSub = nil
    local rotationOffset = Quat.new(0, 0, 0, 1)

    local function getPicPosAndRot()
        local mouseRay = ScreenToWorldRay()
        if not mouseRay then return nil, nil end

        local hit = mouseRay:IntersectAll()
        if not hit or #hit == 0 then
            return nil, nil
        end

        local closestNonPreview = nil --[[@type Hit]]
        for _, h in ipairs(hit) do
            local target = h.Target --[[@as EntityHandle]]
            local targetUuid = target.Uuid and target.Uuid.EntityUuid
            if not targetUuid or targetUuid ~= previewObject then
                closestNonPreview = h
                break
            end
        end

        if closestNonPreview then
            local hitPos = closestNonPreview.Position --[[@as Vec3]]
            local hitRot = MathUtils.DirectionToQuat(closestNonPreview.Normal, nil, "Y")
            return hitPos, hitRot
        end
        return nil, nil
    end

    local startPos, startRot = getPicPosAndRot()

    NetChannel.SpawnPreview:RequestToServer({
        TemplateId = entry.Uuid,
        Position = startPos,
        Rotation = startRot,
    }, function(response)
        if not response.Guid then
            Warning("[IconBrowser] Failed to spawn preview for templateId: " .. tostring(entry.Uuid))
            IsPreviewing = false
            notif:Close()
            notif:Show("Placement Preview Failed", function (panel)
                StyleHelpers.ApplyWarningTooltipStyle(panel)
                panel:AddText("Failed to spawn preview for the selected item.")
            end)
            return
        end
        previewObject = response.Guid

        stickTimer = Timer:EveryFrame(function(timerID)
            if not previewObject then return UNSUBSCRIBE_SYMBOL end

            local hitPos, hitRot = getPicPosAndRot()
            if not hitPos or not hitRot then return end

            if rotationOffset then
                hitRot = Ext.Math.QuatMul(hitRot, rotationOffset)
            end

            NetChannel.SetTransform:SendToServer({
                Guid = previewObject,
                Transforms = {
                    [previewObject] = {
                        Translate = hitPos,
                        RotationQuat = hitRot,
                    }
                }
            })
        end)

        mouseButtonSub = InputEvents.SubscribeMouseInput({}, function(e)
            if not previewObject then return UNSUBSCRIBE_SYMBOL end
            if not e.Pressed and e.Clicks > 0 then return end

            local spawnId = entry.TemplateId or entry.Uuid
            if e.Button == 1 then
                local data = {
                    TemplateId = spawnId,
                    EntInfo = {
                        Position = { RBGetPosition(previewObject) },
                        Rotation = { RBGetRotation(previewObject) }
                    }
                }
                Commands.SpawnCommand(spawnId, data.EntInfo)
            end
        end)

        local deg15 = math.rad(15)
        mouseWheelSub = InputEvents.SubscribeMouseWheel({}, function(e)
            if not previewObject then return UNSUBSCRIBE_SYMBOL end
            if e.ScrollY == 0 then return end

            local angle = deg15 * (e.ScrollY > 0 and 1 or -1)
            local quatOffset = Quat.new(Ext.Math.QuatFromEuler({ 0, angle, 0 }))
            rotationOffset = Ext.Math.QuatMul(quatOffset, rotationOffset)
        end)

        cancelSub = InputEvents.SubscribeKeyInput({}, function(e)
            if not previewObject then
                self.StopPreview()
                return UNSUBSCRIBE_SYMBOL
            end
            if e.Pressed and (e.Key == "ESCAPE" or e.Key == "BACKSPACE") then
                self.StopPreview()
                return UNSUBSCRIBE_SYMBOL
            end
        end)
    end)

    self.StopPreview = function()
        if previewObject then
            NetChannel.Delete:SendToServer({ Guid = previewObject })
            previewObject = nil
        end
        if mouseButtonSub then
            mouseButtonSub:Unsubscribe()
            mouseButtonSub = nil
        end
        if mouseWheelSub then
            mouseWheelSub:Unsubscribe()
            mouseWheelSub = nil
        end
        if stickTimer then
            Timer:Cancel(stickTimer)
            stickTimer = nil
        end
        if cancelSub then
            cancelSub:Unsubscribe()
            cancelSub = nil
        end
        IsPreviewing = false
        notif:Dismiss()
        self.StopPreview = nil
    end
end

function PlacementPreview:IsPreviewing()
    return isPreviewing
end

function PlacementPreview:StartPreview(itemEntry, displayName)
    if self.StopPreview then
        self:StopPreview()
    end

    self:BeginPlacementPreview(itemEntry, displayName)
end