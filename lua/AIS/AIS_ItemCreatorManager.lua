if SERVER then
    util.AddNetworkString("AIS_ItemCreatorManager")

    local function CreateItem(ply, itemID)
        if not ply:IsAdmin() then return end
        if not AIS_Items[itemID] then return end

        local item = ents.Create("AIS_ItemENT")
        if not IsValid(item) then return end

        item:SetPos(ply:GetEyeTrace().HitPos + Vector(0, 0, 10))
        item:SetAngles(Angle(0,0,0))
        item:SetItemID(itemID)
        item:Spawn()
        item:Activate()

        undo.Create("AIS Item Creation")
        undo.AddEntity(item)
        undo.SetPlayer(ply)
        undo.Finish()
    end

    net.Receive("AIS_ItemCreatorManager", function(len, ply)
        local itemID = net.ReadString()
        CreateItem(ply, itemID)
    end)

    CreateConVar("AIS_DropInventoryOnDeath", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Does players' inventories drop on death?")
    CreateConVar("AIS_DropOnlyEquipped", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Drop only equipped items on death?")
    
    hook.Add("PlayerDeath", "AIS_ItemCreatorManager_Death", function(ply)
        if not GetConVar("AIS_DropInventoryOnDeath"):GetBool() then return end

        local dropOnlyEquipped = GetConVar("AIS_DropOnlyEquipped"):GetBool()
        local dropSource = dropOnlyEquipped and AIS_EquipedSlots[ply] or AIS_PlayerInventories[ply]
        if not dropSource then return end

        local origin = ply:WorldSpaceCenter()
        local itemCount = table.Count(dropSource)
        if itemCount == 0 then return end

        local angleStep = 360 / itemCount
        local currentAngle = 0

        for itemID, itemData in pairs(dropSource) do
            if itemData then
                local item = ents.Create("AIS_ItemENT")
                if not IsValid(item) then continue end

                -- Oblicz offset w okręgu
                local rad = math.rad(currentAngle)
                local radius = 8
                local offset = Vector(math.cos(rad), math.sin(rad), 0) * radius
                local pos = origin + offset

                item:SetPos(pos)
                item:SetAngles(Angle(0, 0, 0))
                item:SetItemID(itemData)
                item:Spawn()
                item:Activate()

                local phys = item:GetPhysicsObject()
                if IsValid(phys) then
                    local forceRadius = 20
                    local upForce = 150

                    local dir = Vector(math.cos(rad), math.sin(rad), 0)
                    local force = dir * forceRadius + Vector(0, 0, upForce)

                    phys:SetVelocity(force)
                end

                currentAngle = currentAngle + angleStep
            end
        end

        if dropOnlyEquipped then
            AIS_EquipedSlots[ply] = {}
            ply:UpdateInventory("Equipped")
        else
            AIS_PlayerInventories[ply] = {}
            AIS_EquipedSlots[ply] = {}
            ply:UpdateInventory("All")
        end
    end)
end

if CLIENT then
    local function AIS_ItemCreatorMenu()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("AIS Item Creator")
        frame:SetSize(600, 600)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(false)
        frame:SetDraggable(true)

        local itemlist = vgui.Create("DIconLayout", frame)
        itemlist:Dock(FILL)
        itemlist:SetSpaceX(11)
        itemlist:SetSpaceY(11)
        itemlist:DockMargin(10, 10, 10, 10)
        for itemID, data in pairs(AIS_Items) do
            if data.ShowInMenu ~= nil and data.ShowInMenu == false then continue end
            local icon = itemlist:Add("DButton")
            icon:SetSize(64, 64)
            icon:SetText("")
            icon:SetTooltip(data.Name)
            local BGColor = Color(50, 50, 50, 255)

            icon.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, BGColor)
                surface.SetMaterial(Material(data.Icon))
                surface.SetDrawColor(255, 255, 255)
                surface.DrawTexturedRect(0, 0, w, h)
            end

            icon.DoClick = function()
                net.Start("AIS_ItemCreatorManager")
                net.WriteString(itemID)
                net.SendToServer()
                surface.PlaySound("AIS_UI/item_crate_drop.wav")
            end

            icon.OnCursorEntered = function()
                BGColor = Color(0, 197, 154)
                surface.PlaySound("AIS_UI/panel_open.wav")
            end

            icon.OnCursorExited = function()
                BGColor = Color(50, 50, 50, 255)
            end
        end

        local closeButton = vgui.Create("DButton", frame)
        closeButton:SetText("Close")
        closeButton:SetSize(100, 30)
        closeButton:SetPos(frame:GetWide() - 110, frame:GetTall() - 40)
        closeButton.DoClick = function()
            frame:Close()
            LocalPlayer():EmitSound("AIS_UI/quest_folder_close.wav")
        end
    end

    concommand.Add("AIS_ItemCreator", function()
        LocalPlayer():EmitSound("AIS_UI/quest_folder_close_halloween.wav")
        AIS_ItemCreatorMenu()
    end)
end