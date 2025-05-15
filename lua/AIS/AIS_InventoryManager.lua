if SERVER then
    util.AddNetworkString("AIS_InventoryUpdater")
    util.AddNetworkString("AIS_ManageInventory")

    -- Nowe tabele przechowujące dane ekwipunku i slotów
    AIS_PlayerInventories = {}  -- { player: {item: true, ...} }
    AIS_EquipedSlots = {}       -- { player: {slot_name: item_name, ...} }

    -- Hook do inicjalizacji ekwipunku gracza
    hook.Add("PlayerInitialSpawn", "SetupEquippedItems", function(ply)
        AIS_PlayerInventories[ply] = {}  -- Tworzymy nowy ekwipunek
        AIS_EquipedSlots[ply] = {}       -- Tworzymy nowy zestaw slotów
    end)

    local PLAYER = FindMetaTable("Player")
    print(AIS_DebugMode)

    -- Funkcja dodawania przedmiotu do ekwipunku
    function PLAYER:AddAISItem(item)

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

            -- Aktualizacja klienta
            net.Start("AIS_ManageInventory")
            net.WriteString("Add")
            net.WriteString(item)
            net.Send(self)
        else
            if AIS_DebugMode then
                print("[AIS SERVER] Item already in inventory: " .. item)
            end
        end
    end

    -- Funkcja usuwania przedmiotu z ekwipunku
    function PLAYER:RemoveAISItem(item)

        if AIS_Items[item] == nil then
            print("[AIS SERVER] Item not found: " .. item)
            return
        end
        
        if AIS_PlayerInventories[self] and AIS_PlayerInventories[self][item] then
            AIS_PlayerInventories[self][item] = nil
            if AIS_DebugMode then
                print("[AIS SERVER] Removed item from inventory: " .. item)
            end

            -- Aktualizacja klienta
            net.Start("AIS_ManageInventory")
            net.WriteString("Remove")
            net.WriteString(item)
            net.Send(self)
        else
            if AIS_DebugMode then
                print("[AIS SERVER] Item not found in inventory: " .. item)
            end
        end
    end

    -- Komenda testowa do dodawania przedmiotów do ekwipunku
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

    

    -- Obsługa zarządzania ekwipunkiem
    net.Receive("AIS_ManageInventory", function(_, ply)
        local action = net.ReadString()
        local InvPlayer = net.ReadPlayer()
        local item = net.ReadString()
        local slot = net.ReadString()

        if AIS_DebugMode then
            print("[AIS SERVER] Manage Inventory: " .. action .. " | Item: " .. item .. " | Slot: " .. slot)
        end

        if not AIS_PlayerInventories[InvPlayer] then
            AIS_PlayerInventories[InvPlayer] = {}
        end

        if not AIS_EquipedSlots[InvPlayer] then
            AIS_EquipedSlots[InvPlayer] = {}
        end

        if action == "Equip" then
            if not AIS_PlayerInventories[InvPlayer][item] then
                if AIS_DebugMode then
                    print("[AIS SERVER] Equip failed: player doesn't have item " .. item)
                end
                return
            end
            AIS_EquipedSlots[InvPlayer][slot] = item

        elseif action == "Unequip" then
            if AIS_EquipedSlots[InvPlayer][slot] == item then
                AIS_EquipedSlots[InvPlayer][slot] = nil
            end

        elseif action == "Destroy" then
            -- Spróbuj znaleźć slot, jeśli nie podano
            if slot == "" or not slot then
                for s, v in pairs(AIS_EquipedSlots[InvPlayer]) do
                    if v == item then
                        slot = s
                        break
                    end
                end
            end

            -- Jeśli item był założony – zdejmij go
            if slot and AIS_EquipedSlots[InvPlayer][slot] == item then
                AIS_EquipedSlots[InvPlayer][slot] = nil
                if AIS_DebugMode then
                    print("[AIS SERVER] Destroy: unequipped item " .. item .. " from slot " .. slot)
                end
            end

            -- Usuń z inventory
            AIS_PlayerInventories[InvPlayer][item] = nil
            if AIS_DebugMode then
                print("[AIS SERVER] Destroyed item " .. item)
            end
        end
    end)
end



if CLIENT then

    -- Zmienna przechowująca dane ekwipunku gracza na kliencie
    PlayerInventory = {}  -- {item: true, ...}
    PlayerEquippedItems = {}  -- {slot_name: item_name, ...}
    
    local PLAYERCLIENT = FindMetaTable("Player")

    -- Odbieranie zaktualizowanego ekwipunku
    net.Receive("AIS_InventoryUpdater", function()
        PlayerInventory = net.ReadTable()
        if AIS_DebugMode then
            print("[AIS CLIENT] Player Inventory Updated: ", PlayerInventory)
        end
        notification.AddLegacy("[AIS] Your inventory has been updated!", NOTIFY_GENERIC, 5)
    end)

    -- Odbieranie akcji zarządzania ekwipunkiem
    net.Receive("AIS_ManageInventory", function()
        local action = net.ReadString()
        local item = net.ReadString()

        if action == "Add" then
            PlayerInventory[item] = true
            if AIS_DebugMode then
                print("[AIS CLIENT] Added item to inventory: " .. item .. " | Calling revalidate...")
            end
            notification.AddLegacy("[AIS] Obtained: " .. AIS_Items[item].Name, NOTIFY_GENERIC, 5)

        elseif action == "Remove" then
            PlayerInventory[item] = nil
            if AIS_DebugMode then
                print("[AIS CLIENT] Removed item from inventory: " .. item  .. " | Calling revalidate...")
            end
            notification.AddLegacy("[AIS] Removed: " .. AIS_Items[item].Name, NOTIFY_GENERIC, 5)
        end

        -- Rewalidacja ekwipunku (np. odświeżenie GUI)
        AIS_InventoryGridRevalidate()
    end)

    -- Funkcja zwracająca ekwipunek gracza
    function PLAYERCLIENT:GetAISInventory()
        return PlayerInventory
    end

    -- Funkcja ekwipowania przedmiotu
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

        net.Start("AIS_ManageInventory")
        net.WriteString("Equip")
        net.WritePlayer(LocalPlayer())
        net.WriteString(item)
        net.WriteString(slot)
        net.SendToServer()
    end

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

        -- Tu możesz pominąć ItemFitSlot jeśli po stronie klienta przedmiot już był przypisany do slotu.
        -- Ale jeśli chcesz zabezpieczenie: odkomentuj poniżej:
        -- if not ItemFitSlot(slot, itemData) then
        --     print("[AIS CLIENT] Unequip Item failed: slot does not match item requirements.")
        --     return
        -- end

        if AIS_DebugMode then
            print("[AIS CLIENT] Unequipped item: " .. item .. " from slot: " .. tostring(slot))
        end
        PlayerEquippedItems[slot] = nil

        net.Start("AIS_ManageInventory")
        net.WriteString("Unequip")
        net.WritePlayer(LocalPlayer())
        net.WriteString(item)
        net.WriteString(slot)
        net.SendToServer()
    end

    function PLAYERCLIENT:DestroyItem(item)
        if not item then
            if AIS_DebugMode then
                print("[AIS CLIENT] Destroy Item failed: item is invalid.")
            end
            return
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

        -- Znajdź slot, w którym item jest założony
        local foundSlot = nil
        for slot, equippedItem in pairs(PlayerEquippedItems) do
            if equippedItem == item then
                foundSlot = slot
                break
            end
        end

        -- Usuń ze slotu jeśli był założony
        if foundSlot then
            self:UnequipItem(item, foundSlot)
        end

        if AIS_DebugMode then
            print("[AIS CLIENT] Destroyed item: " .. item .. (foundSlot and (" from slot " .. foundSlot) or " (not equipped)"))
        end

        net.Start("AIS_ManageInventory")
            net.WriteString("Destroy")
            net.WritePlayer(LocalPlayer())
            net.WriteString(item)
            net.WriteString(foundSlot or "") -- pusty string, jeśli nie było slotu
        net.SendToServer()
    end


end

