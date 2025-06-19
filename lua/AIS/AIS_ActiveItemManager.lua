if SERVER then

    util.AddNetworkString("AIS_UseActiveItem")
    
    AIS_ActiveItemPlayerManager = {}
    AIS_UseCooldowns = AIS_UseCooldowns or {}

    net.Receive("AIS_UseActiveItem", function(len, ply)
        local item = net.ReadString()
        local itemData = AIS_Items[item]
        
        if not itemData or not isfunction(itemData.OnUse) then
            if AIS_DebugMode then
                print("[AIS SERVER] Tried to use invalid or non-usable item: " .. tostring(item))
            end
            return
        end

        local manager = AIS_ActiveItemPlayerManager[ply]

        if not manager or type(manager) ~= "table" or not table.HasValue(manager, item) then
            if AIS_DebugMode then
                print("[AIS SERVER] Item not in ActiveItem list: " .. tostring(item))
            end
            return
        end

        -- Cooldown check
        AIS_UseCooldowns[ply] = AIS_UseCooldowns[ply] or {}
        local cooldown = itemData.OnUseCooldown or 0
        local lastUse = AIS_UseCooldowns[ply][item] or 0

        if CurTime() < lastUse + cooldown then
            if AIS_DebugMode then
                print("[AIS SERVER] Item is on cooldown: " .. item .. " (" .. math.Round((lastUse + cooldown) - CurTime(), 2) .. "s left)")
            end
            return
        end

        -- Execute OnUse
        local args = itemData.ExtraUseArgs or {}
        itemData.OnUse(ply, item, unpack(args))
        AIS_UseCooldowns[ply][item] = CurTime()

        if AIS_DebugMode then
            print("[AIS SERVER] Executed OnUse for item: " .. item .. " (Player: " .. ply:Nick() .. ")")
        end
    end)

end

if CLIENT then

    AIS_LocalPlayerActiveItemManager = {
        Current = nil,
        List = {}
    }
    AIS_LocalPlayerUseCooldowns = AIS_LocalPlayerUseCooldowns or {}

    local activeItemIndex = 1

    local function UseActiveItem()
        local manager = AIS_LocalPlayerActiveItemManager
        if not manager or not manager.List or #manager.List == 0 then return end

        local item = manager.List[manager.Current or 1]
        if not item then return end

        local itemData = AIS_Items[item]
        if not itemData then return end

        AIS_LocalPlayerUseCooldowns = AIS_LocalPlayerUseCooldowns or {}
        local lastUse = AIS_LocalPlayerUseCooldowns[item] or 0
        local cooldown = itemData.OnUseCooldown or 0

        if CurTime() < lastUse + cooldown then
            if AIS_DebugMode then print("[AIS CLIENT] Item on cooldown: " .. item) end
            return
        end

        AIS_LocalPlayerUseCooldowns[item] = CurTime()

        net.Start("AIS_UseActiveItem")
        net.WriteString(item)
        net.SendToServer()

        if itemData.OnUseClient then
            itemData.OnUseClient(LocalPlayer(), item)
        end

        if AIS_DebugMode then print("[AIS CLIENT] Used active item: " .. item) end
    end


    local function CycleActiveItem()
        local manager = AIS_LocalPlayerActiveItemManager
        if not manager or not manager.List or #manager.List == 0 then return end

        activeItemIndex = activeItemIndex + 1
        if activeItemIndex > #manager.List then activeItemIndex = 1 end

        manager.Current = activeItemIndex

        if AIS_DebugMode then
            print("[AIS CLIENT] Switched active item to index: " .. activeItemIndex .. " (" .. manager.List[activeItemIndex] .. ")")
        end

    end

    concommand.Add("+AISUseActiveItem", function()
        UseActiveItem()
    end)

    concommand.Add("+AISCycleActiveItem", function()
        CycleActiveItem()
    end)

    local function drawCooldownCircle(x, y, radius, fraction)
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

        surface.SetDrawColor(255, 0, 0, 200)  -- czerwony z delikatną przezroczystością (możesz zmienić)
        draw.NoTexture()
        surface.DrawPoly(vertices)
    end


    hook.Add("HUDPaint", "AIS_DrawActiveItem", function()
        local manager = AIS_LocalPlayerActiveItemManager
        if not manager or not manager.List or #manager.List == 0 then return end

        local activeItemIndex = manager.Current or 1
        local item = manager.List[activeItemIndex]
        --local NextItem = manager.List[activeItemIndex + 1] or manager.List[1]
        --local PrevItem = manager.List[activeItemIndex + 2] or manager.List[#manager.List]
        if not item then return end
        local itemData = AIS_Items[item]
        if not itemData then return end

        local bindString = input.LookupBinding("+AISUseActiveItem")
        if not bindString or bindString == "" then
            bindString = "NO BIND"
        end

        local BGBindWidth, BGBindHeight = surface.GetTextSize(bindString)

        local iconX, iconY = ScrW() / 2, ScrH() - 32
        local iconSize = 64

        -- Draw background
        surface.SetMaterial(Material("materials/notification_bg.png"))
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawTexturedRectRotated(iconX, iconY, 168, 64, 0)

        -- Draw icon
        surface.SetMaterial(Material(itemData.Icon) or Material("materials/ais/default_item_icon.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRectRotated(iconX, iconY, iconSize, iconSize, 0)

        -- Draw bind info
        if bindString ~= "NO BIND" then
            draw.RoundedBox(8, iconX - 13, ScrH() - 90, 20, 20, Color(255, 255, 255, 200))
        end
        draw.SimpleTextOutlined(bindString, "DermaDefault", iconX - 2, ScrH() - 82, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(255, 255, 255, 255))

        AIS_LocalPlayerUseCooldowns = AIS_LocalPlayerUseCooldowns or {}

        local cooldownStart = AIS_LocalPlayerUseCooldowns[item] or 0
        local cooldownDuration = itemData.OnUseCooldown or 0

        if cooldownDuration > 0 then
            local timePassed = CurTime() - cooldownStart
            if timePassed < cooldownDuration then
                local fraction = 1 - (timePassed / cooldownDuration)
                drawCooldownCircle(iconX, iconY, iconSize / 2, fraction) -- +2, żeby było lekko większe niż ikona
            end
        end
    end)
end