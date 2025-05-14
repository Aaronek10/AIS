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

    -- Funkcja dodawania przedmiotu do ekwipunku
    function PLAYER:AddAISItem(item)

        if AIS_Items[item] == nil then
            print("[AIS SERVER] Item not found: " .. item)
            return
        end

        if not AIS_PlayerInventories[self] then
            AIS_PlayerInventories[self] = {}
        end

        if not AIS_PlayerInventories[self][item] then
            AIS_PlayerInventories[self][item] = true
            print("[AIS SERVER] Added item to inventory: " .. item)

            -- Aktualizacja klienta
            net.Start("AIS_ManageInventory")
            net.WriteString("Add")
            net.WriteString(item)
            net.Send(self)
        else
            print("[AIS SERVER] Item already in inventory: " .. item)
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
            print("[AIS SERVER] Removed item from inventory: " .. item)

            -- Aktualizacja klienta
            net.Start("AIS_ManageInventory")
            net.WriteString("Remove")
            net.WriteString(item)
            net.Send(self)
        else
            print("[AIS SERVER] Item not found in inventory: " .. item)
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

        print("[AIS SERVER] Manage Inventory: " .. action .. " | Item: " .. item .. " | Slot: " .. slot)

        -- Sprawdzanie czy gracz ma ekwipunek
        if not AIS_PlayerInventories[InvPlayer] then
            AIS_PlayerInventories[InvPlayer] = {}  -- Tworzymy nowy ekwipunek
        end

        if not AIS_EquipedSlots[InvPlayer] then
            AIS_EquipedSlots[InvPlayer] = {}  -- Tworzymy nowy zestaw slotów
        end

        if action == "Equip" then
            if not AIS_PlayerInventories[InvPlayer][item] then
                print("[AIS SERVER] Equip failed: player doesn't have item " .. item)
                return
            end

            -- Ekwipowanie przedmiotu do slotu
            AIS_EquipedSlots[InvPlayer][slot] = item
            print("[AIS SERVER] Equipped " .. item .. " in slot " .. slot)
            PrintTable(AIS_EquipedSlots[InvPlayer])

        elseif action == "Unequip" then
            if AIS_EquipedSlots[InvPlayer][slot] == item then
                AIS_EquipedSlots[InvPlayer][slot] = nil
                print("[AIS SERVER] Unequipped " .. item .. " from slot " .. slot)
                PrintTable(AIS_EquipedSlots[InvPlayer])
            else
                print("[AIS SERVER] Unequip failed: slot doesn't contain " .. item)
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
        print("[AIS CLIENT] Player Inventory Updated: ", PlayerInventory)
    end)

    -- Odbieranie akcji zarządzania ekwipunkiem
    net.Receive("AIS_ManageInventory", function()
        local action = net.ReadString()
        local item = net.ReadString()

        if action == "Add" then
            PlayerInventory[item] = true
            print("[AIS CLIENT] Added item to inventory: " .. item .. " | Calling revalidate...")

        elseif action == "Remove" then
            PlayerInventory[item] = nil
            print("[AIS CLIENT] Removed item from inventory: " .. item  .. " | Calling revalidate...")
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
            print("[AIS CLIENT] Equip Item failed: item or slot is invalid.")
            return
        end

        local itemInInventory = PlayerInventory[item]
        local itemData = AIS_Items[item]

        if not itemInInventory then
            print("[AIS CLIENT] Equip Item failed: item not found in inventory.")
            return
        end

        if not ItemFitSlot(slot, itemData) then
            print("[AIS CLIENT] Equip Item failed: slot does not match item requirements.")
            return
        end

        print("[AIS CLIENT] Equipped item: " .. item .. " in slot: " .. tostring(slot))
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
            print("[AIS CLIENT] Unequip Item failed: item or slot is invalid.")
            if not item then
                print("[AIS CLIENT] Item is nil.")
            end
            if not slot then
                print("[AIS CLIENT] Slot is nil.")
            end
            return
        end

        local itemData = PlayerInventory[item]
        if not itemData then
            print("[AIS CLIENT] Unequip Item failed: item not found in inventory.")
            return
        end

        -- Tu możesz pominąć ItemFitSlot jeśli po stronie klienta przedmiot już był przypisany do slotu.
        -- Ale jeśli chcesz zabezpieczenie: odkomentuj poniżej:
        -- if not ItemFitSlot(slot, itemData) then
        --     print("[AIS CLIENT] Unequip Item failed: slot does not match item requirements.")
        --     return
        -- end

        print("[AIS CLIENT] Unequipped item: " .. item .. " from slot: " .. tostring(slot))
        PlayerEquippedItems[slot] = nil

        net.Start("AIS_ManageInventory")
        net.WriteString("Unequip")
        net.WritePlayer(LocalPlayer())
        net.WriteString(item)
        net.WriteString(slot)
        net.SendToServer()
    end


end

