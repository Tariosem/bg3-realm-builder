
--- @class CharacterVisualTab : VisualTab
CharacterVisualTab = _Class("CharacterVisualTab", VisualTab)

function CharacterVisualTab:__init(guid)
    VisualTab.__init(self, guid, GetName(guid) .. " - Visuals")
    Debug("CharacterVisualTab:__init", guid)
    self.Guid = guid
end

function CharacterVisualTab:RenderMaterialEditor()  

    if self.materialHeader then
        self.materialHeader:Destroy()
        self.materialHeader = self.panel:AddCollapsingHeader(GetLoca("Material Editor"))
    else
        self.materialHeader = self.panel:AddCollapsingHeader(GetLoca("Material Editor"))
    end

    local entity = Ext.Entity.Get(self.Guid) --[[@as EntityHandle]]
    
    local visual = VisualHelpers.GetEntityVisual(self.Guid)

    if not visual then
        Error("CharacterVisualTab: Could not get visual for entity " .. tostring(self.Guid))
        return
    end

    local cca = entity.CharacterCreationAppearance --[[@as CharacterCreationAppearance]]
    local hairColorRes = Ext.StaticData.Get(cca.HairColor, "CharacterCreationHairColor") --[[@as ResourceCharacterCreationHairColor]]
    local colorEdit = self.materialHeader:AddColorEdit(hairColorRes.DisplayName:Get() or "Hair Color")
    colorEdit.CanDrag = true
    colorEdit.DragDropType = "MaterialPreset"
    colorEdit.Color = hairColorRes.UIColor
    colorEdit.UserData = {
        MaterialProxy = MaterialProxy.new(hairColorRes.MaterialPresetUUID),
    }

    local attachments = visual.Attachments or {}

    for attIndex,attach in ipairs(attachments) do

        local source = attach.Visual.VisualResource and attach.Visual.VisualResource.SourceFile or "Unknown Mesh"
        local attachNode = self.materialHeader:AddTree(GetLastPath(source) .. "##" .. tostring(attIndex))

        for descIndex, obj in ipairs(attach.Visual.ObjectDescs) do
            local objFlags = LightCToArray(obj.Flags)

            local objNode = attachNode:AddTree(obj.Renderable.Model.Name .. "##" .. tostring(attIndex) .. "_" .. tostring(descIndex))
            objNode.OnHoverEnter = function ()
                local visual = VisualHelpers.GetEntityVisual(self.Guid)
                if not visual then
                    return
                end
                local attachments = visual.Attachments or {}
                local attach = attachments[attIndex]
                if not attach then
                    return
                end

                local desc = attach.Visual.ObjectDescs[descIndex]
                if not desc then
                    return
                end

                local renderable = desc.Renderable --[[@as RenderableObject]]
                if not renderable then
                    return
                end


                NetChannel.Visualize:RequestToServer({
                    Type = "Box",
                    Min = renderable.WorldBound.Min,
                    Max = renderable.WorldBound.Max,
                    LineThickness = 0.1,
                    Duration = 2000
                }, function (response)
    
                end)
            end

            local function getliveMat()
                local visual = VisualHelpers.GetEntityVisual(self.Guid)
                if not visual then
                    return nil
                end
                local attachments = visual.Attachments or {}
                local attach = attachments[attIndex]
                if not attach then
                    return nil
                end

                local desc = attach.Visual.ObjectDescs[descIndex]
                if not desc then
                    return nil
                end

                local renderable = desc.Renderable --[[@as RenderableObject]]
                if not renderable then
                    return nil
                end

                local material = renderable.ActiveMaterial
                if not material then
                    return nil
                end

                return material
            end

            local materialEditor = MaterialEditor.new(objNode, obj.Renderable.ActiveMaterial.Material.Name, getliveMat) --[[@as MaterialEditor]]
            materialEditor:Render()

            table.insert(self.Materials, materialEditor)
        end
        ::continue::
    end

end

