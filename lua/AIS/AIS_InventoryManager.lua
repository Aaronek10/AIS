if SERVER then
    util.AddNetworkString("AIS_InventoryUpdater")
    util.AddNetworkString("AIS_ManageInventory")

    -- Tables to store items, player inventories, and equipped slots
    AIS_PlayerInventories = {}  -- { player: {item: true, ...} }
    AIS_EquipedSlots = {}       -- { player: {slot_name: item_name, ...} }

    -- Hook to initialize player inventories and equipped slots when a player spawns
    hook.Add("PlayerInitialSpawn", "SetupEquippedItems", function(ply)
        AIS_PlayerInventories[ply] = {}  -- Tworzymy nowy ekwipunek
        AIS_EquipedSlots[ply] = {}       -- Tworzymy nowy zestaw slotów
    end)

    local PLAYER = FindMetaTable("Entity")

    function FindPlayerByName(name)
        name = string.lower(name)
        for _, ply in ipairs(player.GetAll()) do
            if string.find(string.lower(ply:Nick()), name, 1, true) then
                return ply
            end
        end
    end


    -- Function to add an item to the player's inventory
    function PLAYER:AddAISItem(item, silent)

        if silent == nil then
            silent = false
        end

        if AIS_Items[item] == nil then
            if AIS_DebugMode then
                print("[AIS SERVER] Item not found: " .. item)
            end
            return
        end

        if not AIS_PlayerInventories[self] then
            AIS_PlayerInventories[self] = {}
        end

        if not AIS_PlayerInventories[self][item] then
            AIS_PlayerInventories[self][item] = true
            if AIS_DebugMode then
                print("[AIS SERVER] Added item to inventory: " .. item)
            end

            -- Client update
            net.Start("AIS_ManageInventory")
            net.WriteString("Add")
            net.WriteBool(silent)
            net.WriteString(item)
            net.Send(self)

        else
            if AIS_DebugMode then
                print("[AIS SERVER] Item already in inventory: " .. item)
            end
        end
    end

    -- Function to remove an item from the player's inventory
    function PLAYER:RemoveAISItem(item, silent)

        if silent == nil then
            silent = false
        end

        print("[AIS SERVER] Remove Item: " .. item .. " | Silent: " .. tostring(silent))

        if AIS_Items[item] == nil then
            print("[AIS SERVER] Item not found: " .. item)
            return
        end
        
        if AIS_PlayerInventories[self] and AIS_PlayerInventories[self][item] then

            if AIS_EquipedSlots[self] then
                for slot, equippedItem in pairs(AIS_EquipedSlots[self]) do
                    if equippedItem == item then
                        AIS_EquipedSlots[self][slot] = nil

                        if AIS_DebugMode then
                            print("[AIS SERVER] Unequipped item from slot due to removal: " .. item .. " from slot " .. slot)
                        end

                        local itemData = AIS_Items[item]
                        if itemData and isfunction(itemData.OnUnEquip) then
                            local args = itemData.ExtraUnEquipArgs or {}
                            itemData.OnUnEquip(self, item, unpack(args))
                        end

                        local list = AIS_ActiveItemPlayerManager[self]
                        if list then
                            for i, v in ipairs(list) do
                                if v == item then
                                    table.remove(list, i)

                                    if AIS_DebugMode then
                                        print("[AIS SERVER] Removed Active Item due to removal: " .. item)
                                    end

                                    break
                                end
                            end
                        end

                    end
                end
            end

            AIS_PlayerInventories[self][item] = nil
            if AIS_DebugMode then
                print("[AIS SERVER] Removed item from inventory: " .. item)
            end

            -- Client update
            net.Start("AIS_ManageInventory")
            net.WriteString("Remove")
            net.WriteBool(silent)
            net.WriteString(item)
            net.Send(self)
        else
            if AIS_DebugMode then
                print("[AIS SERVER] Item not found in inventory: " .. item)
            end
        end
    end

    function PLAYER:HasEquippedItem(item)
        local equipped = AIS_EquipedSlots[self]
        if not equipped then return false end

        for _, equippedItem in pairs(equipped) do
            if equippedItem == item then
                return true
            end
        end

        return false
    end

    function PLAYER:HasItemInInventory(item)
        local inventory = AIS_PlayerInventories[self]
        if not inventory then return false end

        return inventory[item] ~= nil
    end

    function PLAYER:UpdateInventory(equip)

        local function SendCompressed(tag, tableData)
            local json = util.TableToJSON(tableData or {})
            local compressed = util.Compress(json)

            net.Start("AIS_InventoryUpdater")
            net.WriteString(tag)
            net.WriteUInt(#compressed, 32)
            net.WriteData(compressed, #compressed)
            net.Send(self)
        end

        if equip == "Equipped" then
            SendCompressed("Equipped", AIS_EquipedSlots[self] or {})
        elseif equip == "All" then
            SendCompressed("Inventory", AIS_PlayerInventories[self] or {})
        end

        if AIS_DebugMode then
            print("[AIS SERVER] Inventory updated for player: " .. self:Nick())
        end
    end



    --[[
    concommand.Add("ais_test", function(ply, cmd, args)
        timer.Simple(5, function() 
            ply:AddAISItem("GlovesTest")
        end)
        timer.Simple(3, function() 
            ply:AddAISItem("ArmorTest")
        end)
        timer.Simple(4, function() 
            ply:AddAISItem("GlovesTestA")
        end)
        ply:AddAISItem("TrinketTestA")
        ply:AddAISItem("TrinketTestB")
    end)
    ]]--

    

    -- Operating on inventory management requests from clients
    net.Receive("AIS_ManageInventory", function(_, ply)
        local action = net.ReadString()
        local InvPlayer = ply
        local item = net.ReadString()
        local slot = net.ReadString()

        if InvPlayer ~= ply then
            print("[AIS SERVER] Inventory management attempted by non-owner player: " .. ply:Nick())
            return
        end

        if AIS_DebugMode then
            print("[AIS SERVER] Manage Inventory: " .. action .. " | Item: " .. item .. " | Slot: " .. slot)
        end

        if not AIS_PlayerInventories[InvPlayer] then
            AIS_PlayerInventories[InvPlayer] = {}
        end

        if not AIS_EquipedSlots[InvPlayer] then
            AIS_EquipedSlots[InvPlayer] = {}
        end

        local itemData = AIS_Items[item]

        if action == "Equip" then
            if not AIS_PlayerInventories[InvPlayer][item] then
                if AIS_DebugMode then
                    print("[AIS SERVER] Equip failed: player doesn't have item " .. item)
                end
                return
            end

            AIS_EquipedSlots[InvPlayer][slot] = item

            if AIS_DebugMode then
                print("[AIS SERVER] Equipped " .. item .. " in slot " .. slot)
                PrintTable(AIS_EquipedSlots[InvPlayer])
            end

            if itemData and isfunction(itemData.OnEquip) then
                local args = itemData.ExtraEquipArgs or {}
                itemData.OnEquip(InvPlayer, item, unpack(args))
            end

            if itemData and isfunction(itemData.OnUse) then
                if not AIS_ActiveItemPlayerManager[ply] then
                    AIS_ActiveItemPlayerManager[ply] = {}
                end

                if not table.HasValue(AIS_ActiveItemPlayerManager[ply], item) then
                    table.insert(AIS_ActiveItemPlayerManager[ply], item)
                end
            end

        elseif action == "Unequip" then
            if AIS_EquipedSlots[InvPlayer][slot] == item then
                AIS_EquipedSlots[InvPlayer][slot] = nil

                if AIS_DebugMode then
                    print("[AIS SERVER] Unequipped " .. item .. " from slot " .. slot)
                    PrintTable(AIS_EquipedSlots[InvPlayer])
                end

                if itemData and isfunction(itemData.OnUnEquip) then
                    local args = itemData.ExtraUnEquipArgs or {}
                    itemData.OnUnEquip(InvPlayer, item, unpack(args))
                end

                local list = AIS_ActiveItemPlayerManager[InvPlayer]
                if list then
                    for i, v in ipairs(list) do
                        if v == item then
                            table.remove(list, i)

                            if AIS_DebugMode then
                                print("[AIS SERVER] Removed Active Item: " .. item)
                            end

                            break
                        end
                    end
                end
                
            else
                if AIS_DebugMode then
                    print("[AIS SERVER] Unequip failed: slot doesn't contain " .. item)
                end
            end
        elseif action == "Destroy" then
            if AIS_EquipedSlots[InvPlayer][slot] == item then
                AIS_EquipedSlots[InvPlayer][slot] = nil

                if AIS_DebugMode then
                    print("[AIS SERVER] Destroyed " .. item .. " from slot " .. slot)
                    PrintTable(AIS_EquipedSlots[InvPlayer])
                end

            end

            AIS_PlayerInventories[InvPlayer][item] = nil

            if AIS_DebugMode then
                print("[AIS SERVER] Destroyed " .. item .. " from inventory")
            end
        elseif action == "UseItem" then
            if not itemData then
                if AIS_DebugMode then
                    print("[AIS SERVER] UseItem failed: item not found " .. item)
                end
                return
            end

            if InvPlayer:HasItemInInventory(item) then
                if isfunction(itemData.OnUse) then
                    local args = itemData.ExtraUseArgs or {}
                    itemData.OnUse(InvPlayer, item, unpack(args))
                else
                    if AIS_DebugMode then
                        print("[AIS SERVER] UseItem failed: OnUse function not defined for " .. item)
                    end
                end
            else
                if AIS_DebugMode then
                    print("[AIS SERVER] UseItem failed: player doesn't have item " .. item)
                end
            end

        else
            if AIS_DebugMode then
                print("[AIS SERVER] Unknown action: " .. action)
            end
        end
    end)


    concommand.Add("AIS_AddItem", function(admin, cmd, args)
        local targetName = args[1]
        local itemID = args[2]

        if not targetName or not itemID then
            print("[AIS] Usage: AIS_AddItem <player> <itemID>")
            return
        end

        local target = FindPlayerByName(targetName)
        if not IsValid(target) then
            print("[AIS] Player not found: " .. tostring(targetName))
            return
        end

        target:AddAISItem(itemID)
    end)

    concommand.Add("AIS_RemoveItem", function(admin, cmd, args)
        local targetName = args[1]
        local itemID = args[2]

        if not targetName or not itemID then
            print("[AIS] Usage: AIS_RemoveItem <player> <itemID>")
            return
        end

        local target = FindPlayerByName(targetName)
        if not IsValid(target) then
            print("[AIS] Player not found: " .. tostring(targetName))
            return
        end

        target:RemoveAISItem(itemID)
    end)

    concommand.Add("AIS_ClearInventory", function(admin, cmd, args)
        local targetName = args[1]

        if not targetName then
            print("[AIS] Usage: AIS_ClearInventory <player>")
            return
        end

        local target = FindPlayerByName(targetName)
        if not IsValid(target) then
            print("[AIS] Player not found: " .. tostring(targetName))
            return
        end

        AIS_PlayerInventories[target] = {}

        if AIS_DebugMode then
            print("[AIS SERVER] Cleared inventory for: " .. target:Nick())
        end

        -- Inform the client about the cleared inventory | Triggers client-side notification and revalidation
        net.Start("AIS_ManageInventory")
        net.WriteString("Clear")
        net.Send(target)
    end)
end



if CLIENT then

    -- Tables to store items, player inventory, and equipped items of local player
    PlayerInventory = {}  -- {item: true, ...}
    PlayerEquippedItems = {}  -- {slot_name: item_name, ...}
    
    local PLAYERCLIENT = FindMetaTable("Player")

    concommand.Add("AIS_ShowAllItems", function()
        if not LocalPlayer():IsAdmin() then
            print("[AIS] You are not an admin!")
            return
        end

        for item, data in pairs(AIS_Items) do
            print("[AIS] ItemID: " .. item .. " | Name: " .. data.Name)
        end
    end)

    -- Receiving the initial inventory from the server
    net.Receive("AIS_InventoryUpdater", function()
        local updateType = net.ReadString()
        local len = net.ReadUInt(32)
        local compressed = net.ReadData(len)
        local json = util.Decompress(compressed)
        local data = util.JSONToTable(json)

        if updateType == "Equipped" then
            PlayerEquippedItems = data or {}
            if AIS_DebugMode then
                print("[AIS CLIENT] Equipped Items Updated (Compressed): ", PlayerEquippedItems)
            end
        elseif updateType == "Inventory" then
            PlayerInventory = data or {}
            PlayerEquippedItems = {}
            if AIS_DebugMode then
                print("[AIS CLIENT] Player Inventory Updated (Compressed): ", PlayerInventory)
            end
        end

        AIS_RefreshInventoryUI()
    end)

    -- Receiving inventory management actions from the server
    net.Receive("AIS_ManageInventory", function()
        local action = net.ReadString()
        local silent = net.ReadBool()
        local item = net.ReadString()

        print("[AIS CLIENT] Manage Inventory Action: " .. action .. " | Item: " .. item .. " | Silent: " .. tostring(silent))

        if action == "Add" then
            PlayerInventory[item] = true

            if AIS_DebugMode then
                print("[AIS CLIENT] Added item to inventory: " .. item .. " | Calling revalidate...")
            end

            if not silent then
                AIS_Notify("Obtained item: " .. AISStripMarkup(AIS_Items[item].Name), nil, AIS_Items[item].Icon, 3, "AIS_UI/panel_close.wav")
            end

        elseif action == "Remove" then
            PlayerInventory[item] = nil

            if AIS_DebugMode then
                print("[AIS CLIENT] Removed item from inventory: " .. item  .. " | Calling revalidate...")
            end

            if not silent then
                AIS_Notify("Removed item: " .. AISStripMarkup(AIS_Items[item].Name), nil, AIS_Items[item].Icon, 3, "AIS_UI/panel_close.wav")
            end

            for i = #AIS_LocalPlayerActiveItemManager.List, 1, -1 do
                if AIS_LocalPlayerActiveItemManager.List[i] == item then
                    table.remove(AIS_LocalPlayerActiveItemManager.List, i)

                    if AIS_LocalPlayerActiveItemManager.Current == i then
                        AIS_LocalPlayerActiveItemManager.Current = 1
                    elseif AIS_LocalPlayerActiveItemManager.Current > #AIS_LocalPlayerActiveItemManager.List then
                        AIS_LocalPlayerActiveItemManager.Current = #AIS_LocalPlayerActiveItemManager.List
                    end
                end
            end

        elseif action == "Clear" then

            PlayerInventory = {}

            if AIS_DebugMode then
                print("[AIS CLIENT] Cleared inventory | Calling revalidate...")
            end

            AIS_LocalPlayerActiveItemManager.List = {}
            AIS_LocalPlayerActiveItemManager.Current = 1
        end
        -- Revalidate the inventory grid to reflect changes
        AIS_InventoryGridRevalidate()
    end)

    -- Function returning the player's inventory
    function PLAYERCLIENT:GetAISInventory()
        return PlayerInventory
    end

    -- Function to equip an item to a specific slot
    function PLAYERCLIENT:EquipItem(item, slot)
        if not item or not slot then
            if AIS_DebugMode then
                print("[AIS CLIENT] Equip Item failed: item or slot is invalid.")
            end
            return
        end

        local itemInInventory = PlayerInventory[item]
        local itemData = AIS_Items[item]

        if not itemInInventory then
            if AIS_DebugMode then
                print("[AIS CLIENT] Equip Item failed: item not found in inventory.")
            end
            return
        end

        if not ItemFitSlot(slot, itemData) then
            if AIS_DebugMode then
                print("[AIS CLIENT] Equip Item failed: slot does not match item requirements.")
            end
            return
        end

        if AIS_DebugMode then
            print("[AIS CLIENT] Equipped item: " .. item .. " in slot: " .. tostring(slot))
        end
        PlayerEquippedItems[slot] = item

        if itemData and isfunction(itemData.OnUse) then
            local activeitemlist = AIS_LocalPlayerActiveItemManager.List
            if not table.HasValue(activeitemlist, item) then
                table.insert(activeitemlist, item)

                -- Jeśli to pierwszy aktywny item, ustaw jako wybrany
                if not AIS_LocalPlayerActiveItemManager.Current then
                    AIS_LocalPlayerActiveItemManager.Current = 1
                end

                if AIS_DebugMode then
                    print("[AIS CLIENT] Added Active Item: " .. item)
                end
            end
        end

        net.Start("AIS_ManageInventory")
            net.WriteString("Equip")
            net.WriteString(item)
            net.WriteString(slot)
        net.SendToServer()
    end

    -- Function to unequip an item from a specific slot
    function PLAYERCLIENT:UnequipItem(item, slot)
        if not item or not slot then
            if AIS_DebugMode then
                print("[AIS CLIENT] Unequip Item failed: item or slot is invalid.")
                if not item then
                    print("[AIS CLIENT] Item is nil.")
                end
                if not slot then
                    print("[AIS CLIENT] Slot is nil.")
                end
            end
            return
        end

        local itemData = PlayerInventory[item]
        if not itemData then
            if AIS_DebugMode then
                print("[AIS CLIENT] Unequip Item failed: item not found in inventory.")
            end
            return
        end

        if AIS_DebugMode then
            print("[AIS CLIENT] Unequipped item: " .. item .. " from slot: " .. tostring(slot))
        end
        PlayerEquippedItems[slot] = nil

        if AIS_Items[item] and isfunction(AIS_Items[item].OnUse) then
            local manager = AIS_LocalPlayerActiveItemManager
            if manager and manager.List then
                local list = manager.List
                for i = #list, 1, -1 do
                    if list[i] == item then
                        table.remove(list, i)

                        if AIS_DebugMode then
                            print("[AIS CLIENT] Removed Active Item: " .. item)
                        end

                        if manager.Current and manager.Current == i then
                            if #list > 0 then
                                manager.Current = ((i - 1) % #list) + 1
                            else
                                manager.Current = nil
                            end
                        elseif manager.Current and manager.Current > i then
                            manager.Current = manager.Current - 1
                        end

                        break
                    end
                end
            end
        end

        net.Start("AIS_ManageInventory")
            net.WriteString("Unequip")
            net.WriteString(item)
            net.WriteString(slot)
        net.SendToServer()
    end

    -- Function to destroy an item (remove it from inventory and unequip if necessary)
    function PLAYERCLIENT:DestroyItem(item)
        if not item then
            if AIS_DebugMode then
                print("[AIS CLIENT] Destroy Item failed: item is invalid.")
            end
            return
        end


        local foundSlot = nil
        for slot, equippedItem in pairs(PlayerEquippedItems) do
            if equippedItem == item then
                foundSlot = slot
                break
            end
        end

        if foundSlot then
            self:UnequipItem(item, foundSlot)
        end

        local itemData = PlayerInventory[item]
        if not itemData then
            if AIS_DebugMode then
                print("[AIS CLIENT] Destroy Item failed: item not found in inventory.")
            end
            return
        else
            PlayerInventory[item] = nil
        end

        if AIS_DebugMode then
            print("[AIS CLIENT] Destroyed item: " .. item .. (foundSlot and (" from slot " .. foundSlot) or " (not equipped)"))
        end

        net.Start("AIS_ManageInventory")
            net.WriteString("Destroy")
            net.WriteString(item)
            net.WriteString(foundSlot or "") -- Empty string if not equipped
        net.SendToServer()
    end

    -- Function to check if the player has a specific item equipped
    function PLAYERCLIENT:HasEquippedItem(item)

        for _, equippedItem in pairs(PlayerEquippedItems) do
            if equippedItem == item then
                return true
            end
        end

        return false
    end

    function PLAYERCLIENT:UseItem(item)
        if not item then
            if AIS_DebugMode then
                print("[AIS CLIENT] Use Item failed: item is invalid.")
            end
            return
        end

        local itemData = AIS_Items[item]
        if not itemData then
            if AIS_DebugMode then
                print("[AIS CLIENT] Use Item failed: item not found in AIS_Items.")
            end
            return
        end

        net.Start("AIS_ManageInventory")
            net.WriteString("UseItem")
            net.WriteString(item)
            net.WriteString("")
        net.SendToServer()

        if itemData.OnUseClient then
            local args = itemData.ExtraUseClientArgs or {}
            itemData.OnUseClient(LocalPlayer(), item, unpack(args))
        end

    end


    local AIS_NotificationQueue = {}
    local AIS_CurrentNotification = nil

    -- Function to notify the player with a message
    -- This function will queue notifications to be displayed on the screen
    function AIS_Notify(text, notifIcon, itemIcon, duration, sound)
        local notif = {
            text = text,
            icon = notifIcon or nil,
            itemIcon = itemIcon or nil,
            notifsound = sound or "AIS_UI/panel_close.wav",
            duration = duration or 5,
            startTime = 0 -- Will be set when the notification is displayed
        }

        table.insert(AIS_NotificationQueue, notif)

        if AIS_DebugMode then
            print("[AIS CLIENT] Notification enqueued: " .. text)
        end
    end

    local NotifBG = Material("materials/notification_bg.png")

    local function drawCirleTime(x, y, radius, fraction, color)
        fraction = math.Clamp(fraction, 0, 1)
        local startAngle = 270  -- punkt startowy (góra)
        local angle = 360 * fraction -- rosnący kąt przeciwnie do ruchu wskazówek zegara

        local vertices = {}
        table.insert(vertices, { x = x, y = y }) -- środek koła

        for i = startAngle, startAngle + angle, 3 do
            local rad = math.rad(i)
            table.insert(vertices, {
                x = x + math.cos(rad) * radius,
                y = y + math.sin(rad) * radius
            })
        end

        if color then
            surface.SetDrawColor(color)
        else
            surface.SetDrawColor(255, 255, 255, 200)  -- domyślny kolor biały z delikatną przezroczystością
        end
        draw.NoTexture()
        surface.DrawPoly(vertices)
    end

    hook.Add("HUDPaint", "AIS_Notifications", function()
        local x = ScrW() / 2
        local y = ScrH() / 2

        if not AIS_CurrentNotification and #AIS_NotificationQueue > 0 then
            AIS_CurrentNotification = table.remove(AIS_NotificationQueue, 1)
            AIS_CurrentNotification.startTime = CurTime()
        end

        local notif = AIS_CurrentNotification
        if not notif then return end

        local icon = notif.icon and Material(notif.icon) or nil
        local itemIcon = notif.itemIcon and Material(notif.itemIcon) or nil
        local text = notif.text or ""
        local notificationSound = notif.notifsound or "AIS_UI/panel_close.wav"

        local timePassed = CurTime() - notif.startTime
        local timeLeft = notif.duration - timePassed

        local alpha = 255
        if timeLeft < 2 then
            alpha = math.Clamp(timeLeft / 2, 0, 1) * 255
        end

        surface.SetFont("ChatFont")
        local textWidth, textHeight = surface.GetTextSize(text)

        surface.SetMaterial(NotifBG)
        surface.SetDrawColor(0, 0, 0, alpha)
        surface.DrawTexturedRect(x - 150, y + 200, 300, 40)

        draw.SimpleText(text, "ChatFont", x, y + 220, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        --[[
        if #AIS_NotificationQueue > 0 then
            --draw.SimpleText("Left: " .. #AIS_NotificationQueue .. " |  Next in: " .. math.Round(timeLeft, 1), "ChatFont", x, y + 250, Color(251, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            drawCirleTime(x, y + 270, 20, timeLeft / notif.duration)
        end
        ]]--

        drawCirleTime(x, y + 250, 20, timeLeft / notif.duration, Color(255, 255, 255, 255 * (timeLeft / notif.duration)))
        drawCirleTime(x, y + 250, 20, 1, Color(0, 0, 0, 255 * (timeLeft / notif.duration)))
        draw.SimpleTextOutlined(string.format("%.1f", timeLeft), "AIS_InventoryFont", x, y + 250, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha))

        if icon then
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawOutlinedRect(x - 25, y + 150, 50, 50, 2)
            surface.SetDrawColor(0, 0, 0, alpha)
            surface.DrawRect(x - 23, y + 152, 46, 46)

            surface.SetMaterial(icon)
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawTexturedRectRotated(x, y + 175, 50, 50, 0)
        elseif itemIcon then
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawOutlinedRect(x - 25, y + 150, 50, 50, 2)
            surface.SetDrawColor(0, 0, 0, alpha)
            surface.DrawRect(x - 23, y + 152, 46, 46)

            surface.SetMaterial(itemIcon)
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawTexturedRectRotated(x, y + 175, 50, 50, 0)
        end

        if notificationSound and not notif.PlayedSound then
            LocalPlayer():EmitSound(notificationSound, 75, 100)
            notif.PlayedSound = true
        end

        if timePassed > notif.duration then
            AIS_CurrentNotification = nil
        end
    end)


end

