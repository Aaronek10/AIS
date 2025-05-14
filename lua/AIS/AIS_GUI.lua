if CLIENT then

    local ply = LocalPlayer()

    local equipmentSlots = {
        "Head", "Torso", "Gloves", "Pants", "Boots", "Trinket 1", "Trinket 2", "Trinket 3", "Trinket 4"
    }

    local ItemTooltip
    hook.Add("Think", "AIS_UpdateItemTooltip", function()

        local x, y = input.GetCursorPos()
        ply.ItemTooltipPos = {x, y}

        if IsValid(ItemTooltip) then
            ItemTooltip:SetPos(ply.ItemTooltipPos[1] + 10, ply.ItemTooltipPos[2] + 10)
        end
    end)

    function ItemFitSlot(slotName, itemData)
        if not itemData or not itemData.Slot then return false end

        local slot = itemData.Slot

        if type(slot) == "string" then
            return slot == slotName
        elseif type(slot) == "table" then
            return table.HasValue(slot, slotName)
        end

        return false
    end


    -- Funkcja do otwierania GUI
    local function OpenAISInventory(user)
        if not IsValid(user) or not user:IsPlayer() then return end
        if IsValid(AISInventoryFrame) then AISInventoryFrame:Remove() end

        ---------------------[MAIN GUI FRAME]---------------------
        AISInventoryFrame = vgui.Create("DFrame")
        AISInventoryFrame:SetSize(ScrW() * 0.9, ScrH() * 0.9)
        AISInventoryFrame:Center()
        AISInventoryFrame:MakePopup()
        AISInventoryFrame:SetDraggable(false)
        AISInventoryFrame:ShowCloseButton(false)
        AISInventoryFrame:SetTitle("")
    
        local margin = 10
        local w, h = AISInventoryFrame:GetSize()
        local third = w / 3
    
        -- Lewa sekcja: ekwipunek
        local inventoryPanel = vgui.Create("DPanel", AISInventoryFrame)
        inventoryPanel:SetPos(margin, margin)
        inventoryPanel:SetSize(third - margin * 2, h - margin * 2)
        inventoryPanel:SetBackgroundColor(Color(40, 40, 40))
    
        -- Środek: playermodel i sloty
        local centerPanel = vgui.Create("DPanel", AISInventoryFrame)
        centerPanel:SetPos(third + margin, margin)
        centerPanel:SetSize(third - margin * 2, h - margin * 2)
        centerPanel:SetBackgroundColor(Color(50, 50, 50))
    
        -- Prawa sekcja: status
        local statusPanel = vgui.Create("DPanel", AISInventoryFrame)
        statusPanel:SetPos(third * 2 + margin, margin)
        statusPanel:SetSize(third - margin * 2, h - margin * 2)
        statusPanel:SetBackgroundColor(Color(40, 40, 40))

        local CloseButton = vgui.Create("DButton", statusPanel)
        CloseButton:SetText("Close Inventory")
        CloseButton:SetSize(100, 30)
        CloseButton:SetPos(statusPanel:GetWide() - 110, 10)
        CloseButton.DoClick = function()
            user:EmitSound("ui/item_bag_drop.wav")
            AISInventoryFrame:Close()
        end

        --------------------------------[MODEL]--------------------------------
        local modelPanel = vgui.Create("DModelPanel", centerPanel)
        modelPanel:Dock(FILL)
        modelPanel:DockMargin(5, 5, 5, 20) -- zostaw miejsce na sloty na dole
        modelPanel:SetModel(user:GetModel())
        modelPanel:SetAnimated(true)
        
        function modelPanel:LayoutEntity(ent)
            ent:SetAngles(Angle(0, 30, 0))
            modelPanel:SetFOV(30)
            ent:SetSequence(user:GetSequence())

            if IsValid(user) then
                for i = 0, user:GetNumBodyGroups() - 1 do
                    local bodygroupValue = user:GetBodygroup(i)
                    ent:SetBodygroup(i, bodygroupValue)
                end
            end
            ent:FrameAdvance(FrameTime())
        end

        local ent = modelPanel.Entity
        local spine = ent:LookupBone("ValveBiped.Bip01_Spine2")
        local lookPos = ent:GetBonePosition(spine) or ent:WorldSpaceCenter()
        
        local mins, maxs = ent:GetRenderBounds()
        local size = math.max(maxs:Distance(mins), 1)
        
        modelPanel:SetCamPos(lookPos + Vector(size, size * 0.5, size * 0.5 - 30))
        modelPanel:SetLookAt(lookPos + Vector(0, 0, -10))

        ----------------------------[EQUIPMENT SLOTS]----------------------------
        local bottomPanel = vgui.Create("DPanel", centerPanel)
        bottomPanel:Dock(BOTTOM)
        bottomPanel:SetTall(180)
        bottomPanel:DockMargin(10, 0, 10, 10)
        bottomPanel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 20, 200))
        end

        -----------------[INVENTORY PANEL]---------------------------------------
        local leftPanel = vgui.Create("DPanel", inventoryPanel)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(inventoryPanel:GetWide() * 0.970)
        leftPanel:DockMargin(10, 10, 5, 10)
        leftPanel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 25, 230))
        end

        -------------------------------------[INVENTORY GRID]--------------------------------
        AISItemGrid = vgui.Create("DIconLayout", leftPanel)
        AISItemGrid:Dock(FILL)
        AISItemGrid:DockMargin(5, 5, 5, 5)
        AISItemGrid:SetSpaceX(5)
        AISItemGrid:SetSpaceY(5)
        AISItemGrid:SetMinimumSize(leftPanel:GetTall(), leftPanel:GetWide())
        AISItemGrid:Receiver("inventorygrid", function(self, panels, dropped, _, x, y)
            if dropped then
                -- Obsłuż przedmiot wracający do gridu
                local item = panels[1]
                local itemData = item.AISItem_Data
                item:SetParent(self)
                item:SetPos(x, y)
                AISItemGrid:InvalidateLayout(true)
                if item.isEquipped then
                    user:UnequipItem(item.AIS_ItemID, itemData.AssignedSlot)
                    item.isEquipped = false
                    item.AssignedSlot = nil
                    user:EmitSound("ui/item_pack_drop.wav")
                end
                -- Dodatkowe operacje (np. zapisz stan)
            end
        end)

        -------------------------------[SLOTS]-------------------------------
        AISslotList = {}

        local function CreateSlot(name, parent)
            local slot = vgui.Create("DPanel", parent)
            slot:SetSize(80, 100)
            slot.ItemOnSlot = nil  -- <==  Stores What is equiped in this slot
            slot.name = name
            table.insert(AISslotList, slot)

            slot.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(40, 40, 40, 255))
                draw.SimpleText(name, "DermaDefaultBold", w / 2, h - 15, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                if not IsValid(self.ItemOnSlot) or table.Count(slot:GetChildren()) == 0 then
                    draw.SimpleText("Empty", "DermaDefault", w / 2, h / 2, Color(120, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            --------------------[DRAG AND DROP EQUIP ON SLOT]----------------
            slot:Receiver("equip-slot:" .. name, function(self, panels, dropped, _, x, y)
                if dropped then
                    local item = panels[1]
                    local itemData = item.AISItem_Data

                    if ItemFitSlot(name, itemData) then
                        if IsValid(self.ItemOnSlot) then
                            user:UnequipItem(self.ItemOnSlot.AIS_ItemID, self.ItemOnSlot.AssignedSlot)
                            self.ItemOnSlot.isEquipped = false
                            self.ItemOnSlot.AssignedSlot = nil
                            self.ItemOnSlot:SetParent(AISItemGrid) 
                            AISItemGrid:InvalidateLayout(true)
                        end
                        item:SetParent(self)
                        item:SetPos(10, panels[1]:GetTall() / 2)
                        item:Droppable("inventorygrid")
                        item.isEquipped = true
                        item.AssignedSlot = name
                        self.ItemOnSlot = item

                        user:EquipItem(item.AIS_ItemID, slot.name)

                        user:EmitSound("ui/item_bag_drop.wav")
                    else
                        user:EmitSound("player/crit_hit_mini4.wav")
                        item:SetParent(AISItemGrid)
                    end
                end
            end)


            return slot
        end


        -------------------[SLOTS ON BOTTOM]-------------------
        local slotContainer = vgui.Create("DHorizontalScroller", bottomPanel)
        slotContainer:Dock(FILL)
        slotContainer:DockMargin(10, 10, 10, 10)

        for _, slotName in ipairs(equipmentSlots) do
            local slot = CreateSlot(slotName, slotContainer)
            slotContainer:AddPanel(slot)
        end

        AIS_InventoryGridRevalidate() -- Sprawdzenie wyposażenia
    end



    -------------------------------[REVALIDATE INVENTORY GRID]-------------------------------
    function AIS_InventoryGridRevalidate()
        if not IsValid(AISInventoryFrame) then return end
        if not IsValid(AISItemGrid) then return end
        AISItemGrid:Clear()
        
        print("[AIS CLIENT] Called Revalidating Inventory Grid!")


        for itemID, isValid in pairs(PlayerInventory) do
            local data = AIS_Items[itemID]
            print("[AIS CLIENT] Found verified item: " .. itemID)
            local itemObject = AISItemGrid:Add("DButton")
            itemObject:SetSize(64, 64)
            itemObject:SetText("")
            itemObject:DockMargin(0, 0, 0, 5)

            if type(data.Slot) == "table" then
                for _, slot in ipairs(data.Slot) do
                    itemObject:Droppable("equip-slot:" .. slot)
                end
            else
                itemObject:Droppable("equip-slot:" .. (data.Slot or "Any"))
            end
            
            itemObject.AIS_ItemID = itemID
            itemObject.AISItem_Data = data

            local BGColor = Color(50, 50, 50, 255)

            itemObject.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, BGColor)
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(Material(data.Icon))
                surface.DrawTexturedRect(5, 5, 54, 54)
            end

            itemObject.DoRightClick = function()
                ply:EmitSound("ui/cyoa_map_open.wav")

                local Itemmenu = DermaMenu()

                if not itemObject.isEquipped then
                    Itemmenu:AddOption("Equip", function()
                        local itemData = itemObject.AISItem_Data
                        if not itemData then return end


                        for _, slot in ipairs(AISslotList) do
                            if IsValid(slot) and ItemFitSlot(slot.name, itemData) and not IsValid(slot.ItemOnSlot) then
                                if IsValid(slot.ItemOnSlot) then
                                    slot.ItemOnSlot:SetParent(AISItemGrid)
                                    AISItemGrid:InvalidateLayout(true)
                                end

                                itemObject:SetParent(slot)
                                itemObject:SetPos(10, itemObject:GetTall() / 2)
                                slot.ItemOnSlot = itemObject
                                itemObject.AssignedSlot = slot.name

                                ply:EquipItem(itemObject.AIS_ItemID, slot.name)

                                itemObject.isEquipped = true
                                itemObject:Droppable("inventorygrid")
                                ply:EmitSound("ui/item_bag_drop.wav")
                                break
                            end
                        end
                    end):SetIcon("icon16/cursor.png")
                else
                    Itemmenu:AddOption("Unequip", function()
                        local slotName = itemObject.AISItem_Data and itemObject.AISItem_Data.Slot
                        if not slotName then return end

                        for _, slot in ipairs(AISslotList) do
                            if IsValid(slot) and slot.ItemOnSlot == itemObject then
                                slot.ItemOnSlot:SetParent(AISItemGrid)
                                AISItemGrid:InvalidateLayout(true)

                                slot.ItemOnSlot = nil
                                ply:UnequipItem(itemObject.AIS_ItemID, slot.name)
                                itemObject.AssignedSlot = nil
                                itemObject.isEquipped = false

                                ply:EmitSound("ui/item_bag_pickup.wav")
                                break
                            end
                        end
                    end):SetIcon("icon16/delete.png")
                end

                Itemmenu:AddOption("Inspect", function()

                    ply:EmitSound("ui/credits_updated.wav")

                    local inspectFrame = vgui.Create("DFrame")
                    inspectFrame:SetSize(300, 200)
                    inspectFrame:Center()
                    inspectFrame:SetTitle(data.Name)
                    inspectFrame:ShowCloseButton(false)
                    inspectFrame:MakePopup()

                    inspectFrame.inspectImage = vgui.Create("DImage", inspectFrame)
                    inspectFrame.inspectImage:SetSize(100, 100)
                    inspectFrame.inspectImage:SetPos(10, inspectFrame:GetTall() / 2 - 50)
                    inspectFrame.inspectImage:SetKeepAspect(true)
                    inspectFrame.inspectImage.Paint = function(self, w, h)
                        draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0))
                        surface.SetDrawColor(255, 255, 255)
                        surface.SetMaterial(Material(data.Icon))
                        surface.DrawTexturedRect(0, 0, w, h)
                    end

                    inspectFrame.inspectDescription = vgui.Create("DLabel", inspectFrame)
                    inspectFrame.inspectDescription:SetPos(120, 20)
                    inspectFrame.inspectDescription:SetText(data.Description)
                    inspectFrame.inspectDescription:SetFont("DermaDefault")
                    inspectFrame.inspectDescription:SetWrap(true)
                    inspectFrame.inspectDescription:SetSize(170, 100)

                    inspectFrame.CloseButton = vgui.Create("DButton", inspectFrame)
                    inspectFrame.CloseButton:SetText("Close")
                    inspectFrame.CloseButton:SetSize(80, 30)
                    inspectFrame.CloseButton:SetPos(210, 160)
                    inspectFrame.CloseButton.DoClick = function()
                        inspectFrame:Close()
                        ply:EmitSound("ui/cyoa_switch.wav")
                    end

                end):SetIcon("icon16/magnifier.png")

                Itemmenu:AddOption("Drop", function()
                    itemObject:Remove()
                    ply:EmitSound("physics/metal/metal_box_break2.wav")
                end)

                Itemmenu:Open()
            end

            itemObject.OnCursorEntered = function()
                if IsValid(ItemTooltip) then ItemTooltip:Remove() end

                BGColor = Color(0, 197, 154)

                ply:EmitSound("ui/cyoa_switch.wav")

                local name = data.Name or "Unknown Item"
                local slot = data.Slot
                local description = data.Description or "No description available."

                -- Jeśli slot to tabela (np. dla Trinketa), ustaw przyjazną nazwę
                local SlotString = "Not specified"
                if slot then
                    if type(slot) == "table" then
                        SlotString = table.concat(slot, ", ")
                    else
                        SlotString = slot
                    end
                end

                -- 🧙 Formatowany opis
                local formattedDesc = string.format(
                    "<font=ChatFont><b>%s</b>\n<color=200,200,200>%s</color>\n<color=150,150,255>Slot: %s</color></font>",
                    name,
                    description,
                    SlotString
                )

                -- Użyjemy markup.Parse żeby automatycznie ogarnąć szerokość i wysokość
                local markup = markup.Parse(formattedDesc, 300) -- 300 = max szerokość tekstu

                ItemTooltip = vgui.Create("DPanel")
                ItemTooltip:SetSize(markup:GetWidth() + 20, markup:GetHeight() + 20)
                ItemTooltip:SetPaintedManually(false)
                ItemTooltip:SetDrawOnTop(true)
                ItemTooltip:SetAlpha(0)

                ItemTooltip.Think = function(self)
                    local curAlpha = self:GetAlpha()
                    local newAlpha = Lerp(FrameTime() * 10, curAlpha, 255)
                    self:SetAlpha(newAlpha)
                end

                ItemTooltip.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, self:GetAlpha() * 0.86))
                    markup:Draw(10, 10, self:GetAlpha())
                end
            end


            itemObject.OnCursorExited = function()
                if IsValid(ItemTooltip) then ItemTooltip:Remove() end
                BGColor = Color(50, 50, 50, 255)
            end


            -------------------[MOVE ITEM TO EQUIPMENT SLOTS]-------------------
            local equippedSlot = nil
            for slotName, equippedID in pairs(PlayerEquippedItems) do
                if equippedID == itemID then
                    equippedSlot = slotName
                    break
                end
            end

            if equippedSlot then
                -- znajdź panel slota o takiej nazwie
                for _, slot in ipairs(AISslotList) do
                    if slot.name == equippedSlot then
                        -- przenieś od razu do slota
                        itemObject:SetParent(slot)
                        itemObject:SetPos(10, itemObject:GetParent():GetTall() / 2 + 20)
                        itemObject:Droppable("inventorygrid")
                        itemObject.isEquipped = true
                        itemObject.AIS_ItemID = itemID
                        itemObject.AssignedSlot = equippedSlot
                        slot.ItemOnSlot = itemObject
                        break
                    end
                end
            end
        end
    end
    
    concommand.Add("Open_AIS_Inventory", function(user)
        if not IsValid(AISInventoryFrame) then
            OpenAISInventory(user)
        end
    end)
end