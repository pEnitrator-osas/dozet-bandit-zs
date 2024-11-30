AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Think()
    local owner = self:GetOwner()
    if self:GetDamage() <= 0 or not (owner:IsPlayer() and owner:Alive()) then
        self:Remove()
        return
    end
    if self.NextBleedTick <= CurTime() then
        local dmg = math.max(self:GetDamage()/50,1) + math.floor(math.Rand(0,2),1)
        local overcap = owner:GetActiveWeapon().OverHeal
        if owner:IsSkillActive(SKILL_BLOODHELL) or owner:GetActiveWeapon().HealFromBleed then
            if owner:Health() < owner:GetMaxHealth() + overcap then
                owner:SetHealth(math.min(owner:Health() + dmg, owner:GetMaxHealth() + overcap)) --хилит на урон равный значению кровотечения
                self:AddDamage(-dmg * 1.5)                                                      --снимает в 1.5 больше чем отхилил
                self.NextBleedTick = CurTime() + math.Clamp(0.1*dmg, 0, 5)                      --задержка между хилами
            end
        else     
            owner:TakeDamage(dmg, self.Damager and self.Damager:IsValid() and self.Damager:IsPlayer() and self.Damager:Team() ~= owner:Team() and self.Damager or owner, self)
            owner:AddLegDamage(dmg)
            self:AddDamage(-dmg)
            local dir = VectorRand()
            dir:Normalize()
            util.Blood(owner:WorldSpaceCenter(), 6, dir, 64)
            self.NextBleedTick = CurTime() + 0.55/math.min(self:GetDamage()/50,1)
        end
    end
    if self.NextStopBleedingTick <= CurTime() then
        local notmoving = (owner:GetVelocity():Length() <= 32)
        if notmoving and !owner:GetActiveWeapon().HealFromBleed then
            self:AddDamage(-2)
        end
        self.NextStopBleedingTick = CurTime() + 0.1
    end
end