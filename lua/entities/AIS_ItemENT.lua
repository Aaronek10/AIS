AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "AIS Base Item"
ENT.Category = "AIS Items"
ENT.Author = "Aaron"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ItemID")
end

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube05x05x05.mdl")
    self:DrawShadow(false)

    if SERVER then

        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(500)
            phys:EnableMotion(true)
            phys:EnableDrag(false)
            phys:EnableGravity(true)
            phys:SetDamping(0, 0.1)
            phys:SetMaterial("gmod_bouncy")

            local upright = constraint.Keepupright(self, Angle(0, 0, 0), 0, 999999)
        end
    end
end


function ENT:DrawTranslucent()
    local itemID = self:GetItemID()
    if not itemID then return end

    local data = AIS_Items[itemID]
    if not data then return end

    local pos = self:WorldSpaceCenter()
    local ang = EyeAngles()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)

    local UniqueOffset = self:EntIndex() * 0.1 -- Unikalne przesunięcie dla każdego przedmiotu
    local floatOffset = math.sin(CurTime() * 2 + UniqueOffset) * 2 -- częstotliwość i amplituda
    local animatedPos = pos + Vector(0, 0, floatOffset)

    cam.Start3D2D(animatedPos, ang, 0.1)
        draw.RoundedBox(4, -64, -64, 150, 150, Color(0, 0, 0, 200))

        -- Ikona
        if data.Icon then
            surface.SetMaterial(Material(data.Icon))
            surface.SetDrawColor(255, 255, 255)
            surface.DrawTexturedRect(-48, -48, 120, 120)
        end

        -- Nazwa
        draw.SimpleTextOutlined(data.Name or itemID, "AIS_InventoryFont", 10, 55, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
    cam.End3D2D()
end

function ENT:Use(activator, caller, useType, value)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local inv = AIS_PlayerInventories[activator]
    local itemID = self:GetItemID()

    if not inv or not inv[itemID] then
        activator:AddAISItem(itemID)
        self:EmitSound("AIS_UI/item_pack_pickup.wav")
        self:Remove()
    else
        activator:ChatPrint("[AIS] You already have this item in your inventory!")
    end
end

function ENT:PhysicsCollide(data, phys)

    local SoundData = {
        "AIS_UI/item_contract_tracker_drop.wav",
        "AIS_UI/item_contract_tracker_pickup.wav",
        "AIS_UI/item_helmet_pickup.wav",
        "AIS_UI/item_helmet_drop.wav"
    }
    self:EmitSound(SoundData[math.random(1, #SoundData)], 75, math.random(90, 110))

end
