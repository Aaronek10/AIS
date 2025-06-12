if CLIENT then

    local localplayer = LocalPlayer()

    hook.Add( "InitPostEntity", "AIS_GUIInitPlayer", function()
	    localplayer = LocalPlayer()
    end )

    local equipmentSlots = {
        "Head", "Chest", "Arms", "Gloves", "Pants", "Boots", "Trinket 1", "Trinket 2", "Trinket 3", "Trinket 4"
    }

    AIS_AttributeLocalization = {
    ArmorPoints = function(val)
        return "<color=255,238,0>Armor: " .. val .. "</color>"
    end,
    ELArmorPoints = function(val)
        return "<color=0,183,255>Elem. Armor: " .. val .. "</color>"
    end,
    }

    function GetItemAttributeBlock(itemData)
        local attr = itemData.Attributes or {}
        local lines = {}

        for key, val in pairs(attr) do
            local formatter = AIS_AttributeLocalization[key]
            if formatter then
                table.insert(lines, formatter(val))
            else
                table.insert(lines, key .. ": " .. tostring(val))
            end
        end

        return table.concat(lines, "\n")
    end

    function CalculateDamageReduction(armor)
        if armor >= 0 then
            return 100 / (100 + armor)
        else
            return 1 + math.abs(armor) / 100
        end
    end

    local ItemTooltip
    hook.Add("Think", "AIS_UpdateItemTooltip", function()

        local x, y = input.GetCursorPos()
        localplayer.ItemTooltipPos = {x, y}
        AIS_DebugMode = GetConVar("AIS_Debug"):GetBool()

        if IsValid(ItemTooltip) then
            ItemTooltip:SetPos(localplayer.ItemTooltipPos[1] + 10, localplayer.ItemTooltipPos[2] + 10)
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

        local AIS_RealismMode = GetConVar("AIS_RealismMode"):GetBool()

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
    
        ----------------------[LEFT PANEL - INVENTORY]--------------------
        local inventoryPanel = vgui.Create("DPanel", AISInventoryFrame)
        inventoryPanel:SetPos(margin, margin)
        inventoryPanel:SetSize(third - margin * 2, h - margin * 2)
        inventoryPanel:SetBackgroundColor(Color(40, 40, 40))
    
        ---------------------[CENTER PANEL - PLAYERMODEL]--------------------
        local centerPanel = vgui.Create("DPanel", AISInventoryFrame)
        centerPanel:SetPos(third + margin, margin)
        centerPanel:SetSize(third - margin * 2, h - margin * 2)
        centerPanel:SetBackgroundColor(Color(50, 50, 50))
    
        --------------------[RIGHT PANEL - STATS PANEL]----------------
        local statusPanel = vgui.Create("DPanel", AISInventoryFrame)
        statusPanel:SetPos(third * 2 + margin, margin)
        statusPanel:SetSize(third - margin * 2, h - margin * 2)
        statusPanel:SetBackgroundColor(Color(40, 40, 40))
        statusPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:GetBackgroundColor())

            local ply = LocalPlayer()
            local y = 10
            local padding = 5
            local font = "TargetID"

            draw.SimpleText("Player: " .. ply:Nick(), font, 10, y, color_white)
            y = y + 20
            draw.SimpleText("Health: " .. ply:Health() .. " / " .. ply:GetMaxHealth(), font, 10, y, Color(200, 255, 200))
            y = y + 30

            draw.SimpleText("EQUIPMENT:", font, 10, y, Color(255, 255, 100))
            y = y + 20

            local totalArmor = 0
            local totalELArmor = 0

            for _, slotPanel in ipairs(AISslotList or {}) do
                local slotName = slotPanel.name
                local itemObj = slotPanel.ItemOnSlot

                local itemData
                if itemObj and itemObj.AIS_ItemID then
                    itemData = AIS_Items[itemObj.AIS_ItemID]
                end

                if itemObj then
                    if itemData then
                        local armor = itemData.Attributes and itemData.Attributes["ArmorPoints"] or 0
                        local elarmor = itemData.Attributes and itemData.Attributes["ELArmorPoints"] or 0

                        draw.SimpleText(string.format("%s: %s - %d ARMOR / %d ELEM. ARMOR", slotName, itemData.Name or "?", armor, elarmor), font, 10, y, Color(200, 200, 255))
                        
                        totalArmor = totalArmor + armor
                        totalELArmor = totalELArmor + elarmor
                    end
                else
                    draw.SimpleText(string.format("%s: (none)", slotName), font, 10, y, Color(100, 100, 100))
                end

                y = y + 20
            end

            y = y + 10
            draw.SimpleText("Summary:", font, 10, y, color_white)
            y = y + 20

            local totalReduction = (1 - CalculateDamageReduction(totalArmor)) * 100
            local totalELReduction = (1 - CalculateDamageReduction(totalELArmor)) * 100

            if not AIS_RealismMode then
                draw.SimpleText(string.format("Armor: %d | Damage Reduction: %.2f%%", totalArmor, totalReduction), font, 10, y, Color(0, 255, 150))
                draw.SimpleText(string.format("Elem. Armor: %d | Damage Reduction: %.2f%%", totalELArmor, totalELReduction), font, 10, y + 20, Color(0, 255, 150))
            else
                local armorGroups = {
                    Head = { "Head" },
                    Chest = { "Chest" },
                    Arms = { "Arms", "Gloves" },
                    Legs = { "Pants", "Boots" }
                }

                local groupTotals = {}

                -- Initialize totals for each group
                for group, slots in pairs(armorGroups) do
                    groupTotals[group] = { armor = 0, elarmor = 0 }
                end

                for _, slotPanel in ipairs(AISslotList or {}) do
                    local slotName = slotPanel.name
                    local itemObj = slotPanel.ItemOnSlot

                    local itemData
                    if itemObj and itemObj.AIS_ItemID then
                        itemData = AIS_Items[itemObj.AIS_ItemID]
                    end

                    if itemObj and itemData then
                        local armor = itemData.Attributes and itemData.Attributes["ArmorPoints"] or 0
                        local elarmor = itemData.Attributes and itemData.Attributes["ELArmorPoints"] or 0

                        for group, slots in pairs(armorGroups) do
                            for _, slot in ipairs(slots) do
                                if string.lower(slotName) == string.lower(slot) then
                                    groupTotals[group].armor = groupTotals[group].armor + armor
                                    groupTotals[group].elarmor = groupTotals[group].elarmor + elarmor
                                end
                            end
                        end
                    end
                end

                -- Wyświetlenie podsumowania per grupa
                for _, group in ipairs({ "Head", "Chest", "Arms", "Legs" }) do
                    local data = groupTotals[group]
                    local armor = data.armor
                    local elarmor = data.elarmor

                    local red = (1 - CalculateDamageReduction(armor)) * 100
                    local elred = (1 - CalculateDamageReduction(elarmor)) * 100

                    draw.SimpleText(
                        string.format("%s: (%d|%d) >> %.2f%% Dmg Red. | %.2f%% Elem. Red.",
                            group, armor, elarmor, red, elred
                        ),
                        font, 10, y, Color(0, 255, 150)
                    )
                    y = y + 20
                end
            end
        end


        --------------------[CLOSE BUTTON]--------------------
        local CloseButton = vgui.Create("DButton", statusPanel)
        CloseButton:SetText("Close Inventory")
        CloseButton:SetSize(100, 30)
        CloseButton:SetPos(statusPanel:GetWide() - 110, 10)
        CloseButton.DoClick = function()
            user:EmitSound("AIS_UI/panel_open.wav")
            AISInventoryFrame:Close()
        end

        --------------------------------[MODEL]--------------------------------
        local modelPanel = vgui.Create("DModelPanel", centerPanel)
        modelPanel:Dock(FILL)
        modelPanel:DockMargin(5, 5, 5, 20) -- Margin for slots on bottom
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
                local item = panels[1]
                local itemData = item.AISItem_Data
                item:SetParent(self)
                item:SetPos(x, y)
                if item.isEquipped then
                    user:UnequipItem(item.AIS_ItemID, item.AssignedSlot)
                    item.AssignedSlot = nil
                    item.isEquipped = false
                    for _, slot in ipairs(AISslotList) do
                        if IsValid(slot) and slot.ItemOnSlot == item then
                            slot.ItemOnSlot = nil
                        end
                    end
                end
                AISItemGrid:InvalidateLayout(true)
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

                        if itemData.EquipSound then
                            localplayer:EmitSound(itemData.UnEquipSound)
                        else
                            localplayer:EmitSound("AIS_UI/item_bag_pickup.wav")
                        end
                    else
                        user:EmitSound("AIS_UI/panel_close.wav")
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

        AIS_InventoryGridRevalidate() -- Revalidate the inventory grid on creation 
    end



    -------------------------------[REVALIDATE INVENTORY GRID]-------------------------------
    function AIS_InventoryGridRevalidate()
        if not IsValid(AISInventoryFrame) then return end
        if not IsValid(AISItemGrid) then return end
        AISItemGrid:Clear()
        if AIS_DebugMode then
            print("[AIS CLIENT] Called Revalidating Inventory Grid!")
        end


        for itemID, isValid in pairs(PlayerInventory) do
            local data = AIS_Items[itemID]
            if AIS_DebugMode then
                print("[AIS CLIENT] Found verified item: " .. itemID)
            end
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
                localplayer:EmitSound("AIS_UI/slide_up.wav")

                local Itemmenu = DermaMenu()

                if not itemObject.isEquipped then
                    Itemmenu:AddOption("Equip", function()
                        local itemData = itemObject.AISItem_Data
                        if not itemData then return end
                        for _, slot in ipairs(AISslotList) do
                            if IsValid(slot) and ItemFitSlot(slot.name, itemData) and not IsValid(slot.ItemOnSlot) then
                                itemObject:SetParent(slot)
                                itemObject:SetPos(10, itemObject:GetTall() / 2)
                                slot.ItemOnSlot = itemObject
                                itemObject.AssignedSlot = slot.name

                                localplayer:EquipItem(itemObject.AIS_ItemID, slot.name)

                                itemObject.isEquipped = true
                                itemObject:Droppable("inventorygrid")
                                if itemObject.AISItem_Data.EquipSound then
                                    localplayer:EmitSound(itemObject.AISItem_Data.EquipSound)
                                else
                                    localplayer:EmitSound("AIS_UI/item_bag_drop.wav")
                                end
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

                                localplayer:UnequipItem(itemObject.AIS_ItemID, slot.name)
                                itemObject.AssignedSlot = nil
                                itemObject.isEquipped = false
                                slot.ItemOnSlot = nil

                                if itemObject.AISItem_Data.UnEquipSound then
                                    localplayer:EmitSound(itemObject.AISItem_Data.UnEquipSound)
                                else
                                    localplayer:EmitSound("AIS_UI/item_bag_pickup.wav")
                                end
                                break
                            end
                        end
                    end):SetIcon("icon16/delete.png")
                end

                Itemmenu:AddOption("Inspect", function()

                    localplayer:EmitSound("AIS_UI/quest_folder_open.wav")

                    local inspectFrame = vgui.Create("DFrame")
                    inspectFrame:SetSize(800, 500)
                    inspectFrame:Center()
                    inspectFrame:SetTitle(data.Name or "Inspect")
                    inspectFrame:ShowCloseButton(true)
                    inspectFrame:MakePopup()

                    -- Icon of item
                    inspectFrame.inspectImage = vgui.Create("DImage", inspectFrame)
                    inspectFrame.inspectImage:SetSize(400, 400)
                    inspectFrame.inspectImage:SetPos(10, inspectFrame:GetTall() / 2 - 200)
                    inspectFrame.inspectImage:SetKeepAspect(true)
                    inspectFrame.inspectImage.Paint = function(self, w, h)
                        draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0))
                        surface.SetDrawColor(255, 255, 255)
                        surface.SetMaterial(Material(data.Icon))
                        surface.DrawTexturedRect(0, 0, w, h)
                    end

                    local attributeLines = ""
                    if data.Attributes then
                        for key, value in pairs(data.Attributes) do
                            local formatter = AIS_AttributeLocalization[key]
                            if formatter then
                                attributeLines = attributeLines .. formatter(value) .. "\n"
                            else
                                attributeLines = attributeLines .. "<color=200,200,200>" .. key .. ": " .. tostring(value) .. "</color>\n"
                            end
                        end
                    end

                    -- Completed description parsing
                    local parsed = markup.Parse(
                        "<font=ChatFont>" ..
                            "<color=255,255,255><b>Description:</b></color>\n" ..
                            "<color=200,200,200>" .. (data.Description or "No description.") .. "</color>\n\n" ..
                            "<color=150,200,255><b>Stats:</b></color>\n" ..
                            attributeLines ..
                        "</font>",
                        375
                    )


                    -- Description panel
                    inspectFrame.DescriptionPanel = vgui.Create("DPanel", inspectFrame)
                    inspectFrame.DescriptionPanel:SetPos(inspectFrame:GetWide() / 2 + 20, 30)
                    inspectFrame.DescriptionPanel:SetSize(375, parsed:GetHeight() + 20)
                    inspectFrame.DescriptionPanel.Paint = function(self, w, h)
                        parsed:Draw(0, 0, TEXT_ALIGN_LEFT)
                    end

                    -- Close button
                    inspectFrame.CloseButton = vgui.Create("DButton", inspectFrame)
                    inspectFrame.CloseButton:SetText("Close")
                    inspectFrame.CloseButton:SetSize(80, 30)
                    inspectFrame.CloseButton:SetPos(inspectFrame:GetWide() / 2 + 180, 450)
                    inspectFrame.CloseButton.DoClick = function()
                        inspectFrame:Close()
                        localplayer:EmitSound("AIS_UI/quest_folder_close.wav")
                    end

                end):SetIcon("icon16/magnifier.png")


                Itemmenu:AddOption("Remove", function()
                    itemObject:Remove()
                    localplayer:DestroyItem(itemObject.AIS_ItemID)
                    localplayer:EmitSound("AIS_UI/item_shovel_drop.wav")
                end)

                Itemmenu:Open()
            end

            itemObject.OnCursorEntered = function()
                if IsValid(ItemTooltip) then ItemTooltip:Remove() end

                BGColor = Color(0, 197, 154)
                localplayer:EmitSound("AIS_UI/panel_open.wav")

                local name = data.Name or "Unknown Item"
                local slot = data.Slot
                local description = data.Description or "No description available."

                local SlotString = "Not specified"
                if slot then
                    if type(slot) == "table" then
                        SlotString = table.concat(slot, ", ")
                    else
                        SlotString = slot
                    end
                end

                local attributeBlock = GetItemAttributeBlock(data)

                local formattedDesc = string.format(
                    "<font=TargetIDSmall><b>%s</b>\n<color=200,200,200>%s</color>%s\n\n<color=150,150,255>Slot: %s</color></font>",
                    name,
                    description,
                    attributeBlock ~= "" and ("\n\n" .. attributeBlock) or "",
                    SlotString
                )

                -- Parsing and creating the markup
                local markup = markup.Parse(formattedDesc, 300)

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
                for _, slot in ipairs(AISslotList) do
                    if slot.name == equippedSlot then
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
            localplayer:EmitSound("AIS_UI/item_heavy_gun_pickup.wav")
        end
    end)
end