AddCSLuaFile()

if CLIENT then
	SWEP.TranslateName = "weapon_medikit_name"
	SWEP.TranslateDesc = "weapon_medikit_desc"
	SWEP.Slot = 4
	SWEP.SlotPos = 0

	SWEP.ViewModelFOV = 50
	SWEP.ViewModelFlip = false

	SWEP.BobScale = 2
	SWEP.SwayScale = 1.5
end

SWEP.Base = "weapon_zs_base"

SWEP.WorldModel = "models/weapons/w_medkit.mdl"
SWEP.ViewModel = "models/weapons/c_medkit.mdl"
SWEP.UseHands = true

SWEP.Primary.Delay = 0.76
SWEP.Primary.Heal = 10
SWEP.Primary.Automatic = true

SWEP.Primary.ClipSize = 0
SWEP.Primary.DefaultClip = 160
SWEP.Primary.Ammo = "Battery"

SWEP.Secondary.Delay = 9
SWEP.Secondary.Heal = 10

SWEP.Secondary.ClipSize = 1
SWEP.Secondary.DefaultClip = 1
SWEP.Secondary.Ammo = "dummy"

SWEP.WalkSpeed = SPEED_NORMAL

SWEP.HoldType = "slam"

function SWEP:Initialize()
	self:SetWeaponHoldType(self.HoldType)
	self:SetDeploySpeed(1.1)
	if CLIENT then
		if self.TranslateName then
			self.PrintName = translate.Get(self.TranslateName)
		end
	end
end

function SWEP:Think()
	if self.IdleAnimation and self.IdleAnimation <= CurTime() then
		self.IdleAnimation = nil
		self:SendWeaponAnim(ACT_VM_IDLE)
	end
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end
	local owner = self:GetOwner()
	if owner:IsSkillActive(SKILL_FALONE) then return false end

	owner:LagCompensation(true)
	local meleetr = owner:MeleeTrace(32, 2,nil,nil,true)
	local ent = meleetr.Entity
	owner:LagCompensation(false)

	if ent and ent:IsValid() and ent:IsPlayer() and ent:Team() == owner:Team() and ent:Alive() and gamemode.Call("PlayerCanBeHealed", ent) then
		local health, maxhealth = ent:Health(), ent:GetMaxHealth()
		local multiplier = owner.MedicHealMul or 1
		local toheal = math.min(self:GetPrimaryAmmoCount(), math.ceil(math.min(self.Primary.Heal * multiplier, maxhealth - health)))
		local totake = math.ceil(toheal / multiplier)
		if toheal > 0 then
			self:SetNextCharge(CurTime() + (self.Primary.Delay * math.min(1, toheal / self.Primary.Heal)) * (owner.MedicCooldownMul or 1))
			owner.NextMedKitUse = self:GetNextCharge()

			self:TakeCombinedPrimaryAmmo(totake)

			ent:HealHealth(toheal,owner,self)
			self:EmitSound("items/medshot4.wav")
			self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

			owner:DoAttackEvent()
			self.IdleAnimation = CurTime() + self:SequenceDuration()
		end
	end
end

function SWEP:SecondaryAttack()
	if GAMEMODE:GetSpecialWave() == "1hp" then return end
	local owner = self:GetOwner()
	if not self:CanPrimaryAttack() or not gamemode.Call("PlayerCanBeHealed", owner) then return end


	local health, maxhealth = owner:Health(), owner:GetMaxHealth()
	local multiplier = (owner.MedicHealMul or 1) * (owner:IsSkillActive(SKILL_FALONE) and 0.5 or 1)
	local toheal = math.min(self:GetPrimaryAmmoCount(), math.ceil(math.min(self.Secondary.Heal * multiplier, maxhealth - health)))
	local totake = math.ceil(toheal / multiplier)
	if toheal > 0 then
		self:SetNextCharge(CurTime() + ((self.Secondary.Delay * math.min(1, toheal / self.Secondary.Heal)) * (owner.MedicCooldownMul or 1)) / (owner:IsSkillActive(SKILL_FALONE) and 3 or 1))
		owner.NextMedKitUse = self:GetNextCharge()

		self:TakeCombinedPrimaryAmmo(totake)

		owner:HealHealth(toheal,owner,self)
		self:EmitSound("items/smallmedkit1.wav")

		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

		owner:DoAttackEvent()
		self.IdleAnimation = CurTime() + self:SequenceDuration()
	end
end

function SWEP:Deploy()
	gamemode.Call("WeaponDeployed", self:GetOwner(), self)

	self.IdleAnimation = CurTime() + self:SequenceDuration()

	if CLIENT then
		hook.Add("PostPlayerDraw", "PostPlayerDrawMedical", GAMEMODE.PostPlayerDrawMedical)
		GAMEMODE.MedicalAura = true
	end

	return true
end

function SWEP:Holster()
	if CLIENT then
		hook.Remove("PostPlayerDraw", "PostPlayerDrawMedical")
		GAMEMODE.MedicalAura = false
	end

	return true
end

function SWEP:OnRemove()
	if CLIENT and self:GetOwner() == LocalPlayer() then
		hook.Remove("PostPlayerDraw", "PostPlayerDrawMedical")
		GAMEMODE.MedicalAura = false
	end
end

function SWEP:Reload()
end

function SWEP:SetNextCharge(tim)
	self:SetDTFloat(0, tim)
end

function SWEP:GetNextCharge()
	return self:GetDTFloat(0)
end

function SWEP:CanPrimaryAttack()
	local owner = self:GetOwner()
	if owner:IsHolding() or owner:GetBarricadeGhosting() or self:GetNextCharge() >= CurTime() then return false end


	if self:GetPrimaryAmmoCount() <= 0 then
		self:EmitSound("items/medshotno1.wav")

		self:SetNextCharge(CurTime() + 0.1)
		owner.NextMedKitUse = self:GetNextCharge()
		return false
	end

	return self:GetNextCharge() <= CurTime() and (owner.NextMedKitUse or 0) <= CurTime()
end

if not CLIENT then return end

function SWEP:DrawWeaponSelection(...)
	return self:BaseDrawWeaponSelection(...)
end

local colBG = Color(16, 16, 16, 90)
local colRed = Color(220, 0, 0, 230)
local colYellow = Color(220, 220, 0, 230)
local colWhite = Color(220, 220, 220, 230)
local colAmmo = Color(255, 255, 255, 230)
local function GetAmmoColor(clip, maxclip)
	if clip == 0 then
		colAmmo.r = 255 colAmmo.g = 0 colAmmo.b = 0
	else
		local sat = clip / maxclip
		colAmmo.r = 255
		colAmmo.g = sat ^ 0.3 * 255
		colAmmo.b = sat * 255
	end
end

local texGradDown = surface.GetTextureID("VGUI/gradient_down")
function SWEP:DrawHUD()
	local screenscale = BetterScreenScale()
	local scrW = ScrW()
	local scrH = ScrH()
	local wid = 200
	local hei = 30
	local x, y = (ScrW()- wid)*0.5 , (ScrH() - hei)*0.75
	local timeleft = self:GetNextCharge() - CurTime()
	if 0 < timeleft then
		surface.SetDrawColor(5, 5, 5, 180)
		surface.DrawRect(x, y, wid, hei)

		surface.SetDrawColor(255, 0, 0, 180)
		surface.SetTexture(texGradDown)
		surface.DrawTexturedRect(x, y, math.min(1, timeleft > self.Primary.Delay and (timeleft / self.Secondary.Delay) or (timeleft / self.Primary.Delay)) * wid, hei)

		surface.SetDrawColor(255, 0, 0, 180)
		surface.DrawOutlinedRect(x, y, wid, hei)
	end

	local wid, hei = 180 * screenscale, 64 * screenscale
	local x, y = ScrW() - wid - screenscale * 128, ScrH() - hei - screenscale * 72
	local clip = self:Ammo1()

	draw.RoundedBox(16, x, y, wid, hei, colBG)
	local font = "ZSHUDFontBig"
	if clip >= 1000 then
		font = "ZSHUDFontSmall"
	elseif clip >= 100 then
		font = "ZSHUDFont"
	end
	GetAmmoColor(clip, 160)
	draw.SimpleTextBlurry(clip, font, x + wid * 0.5, y + hei * 0.5, colAmmo, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
	if GetConVarNumber("crosshair") == 1 then
		self:DrawCrosshairDot()
	end
end
