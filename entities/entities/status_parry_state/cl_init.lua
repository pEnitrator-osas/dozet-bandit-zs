include("shared.lua")
include("animations.lua")

SWEP.PrintName = "" -- We are no longer using PrintName.
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.ViewModelFOV = 60

SWEP.Slot = 0
SWEP.SlotPos = 0

function SWEP:TranslateFOV(fov)
	return GAMEMODE.FOVLerp * fov
end

function SWEP:DrawWeaponSelection(...)
	return self:BaseDrawWeaponSelection(...)
end

local texGradDown = surface.GetTextureID("VGUI/gradient_down")
function SWEP:DrawHUD()
	if self:GetParryCD() > CurTime() then
		local scrW = ScrW()
		local scrH = ScrH()
		local width = 100
		local height = 7
		local x, y = ScrW()*0.5 - width*0.5 , ScrH()*0.5 + height*3
		local ratio = math.max(self:GetParryCD()-CurTime(), 0)/((self.ParryWindow+(self:GetOwner():IsSkillActive(SKILL_PARRY_SLOW) and 0.3 or 0))*5)
		if ratio > 0 then
			surface.SetDrawColor(5, 5, 5, 180)
			surface.DrawRect(x, y, width, height)
			surface.SetTexture(0)
			surface.SetDrawColor(255, 255, 0, 180)
			surface.DrawTexturedRect(x, y, width*ratio, height) 
			surface.SetTexture(texGradDown)
			surface.SetDrawColor(255, 128, 0, 180)
			surface.DrawTexturedRect(x, y, width*ratio, height)
			surface.SetDrawColor(5, 5, 0, 180)
			surface.DrawOutlinedRect(x - 1, y - 1, width + 2, height + 2) 
		end
		--draw.SimpleText("Parry Cooldown: "..self:GetParryCD()-CurTime(), "ZSHUDFontSmallest", x, y - height*5)
	end
	if GetConVarNumber("crosshair") ~= 1 then return end
	self:DrawCrosshairDot()
end

function SWEP:OnRemove()
	self:Anim_OnRemove()
end

function SWEP:ViewModelDrawn()
	self:Anim_ViewModelDrawn()
end

function SWEP:PreDrawViewModel(vm)
	if self.ShowViewModel == false then
		render.SetBlend(0)
	end
end

function SWEP:PostDrawViewModel(vm)
	if self.ShowViewModel == false then
		render.SetBlend(1)
	end
end

function SWEP:DrawWorldModel()
	local owner = self:GetOwner()
	if owner:IsValid() and owner.ShadowMan then return end

	self:Anim_DrawWorldModel()
end

local ghostlerp = 0
local ghostlerp1 = 0
function SWEP:GetViewModelPosition(pos, ang)
	if self:IsSwinging() then
		local rot = self.SwingRotation
		local offset = self.SwingOffset

		ang = Angle(ang.pitch, ang.yaw, ang.roll) -- Copy

		local swingend = self:GetSwingEnd()
		local delta = self.SwingTime - math.Clamp(swingend - CurTime(), 0, self.SwingTime)
		local power = CosineInterpolation(0, 1, delta / self.SwingTime)

		if power >= 0.9 then
			power = (1 - power) ^ 0.4 * 2
		end

		pos = pos + offset.x * power * ang:Right() + offset.y * power * ang:Forward() + offset.z * power * ang:Up()

		ang:RotateAroundAxis(ang:Right(), rot.pitch * power)
		ang:RotateAroundAxis(ang:Up(), rot.yaw * power)
		ang:RotateAroundAxis(ang:Forward(), rot.roll * power)
	end

	if self:GetOwner():GetBarricadeGhosting() then
		ghostlerp = math.min(1, ghostlerp + FrameTime() * 4)
	elseif ghostlerp > 0 then
		ghostlerp = math.max(0, ghostlerp - FrameTime() * 5)
	end
	if not self:GetBlock() then
		ghostlerp1 = math.max(0, ghostlerp1 - FrameTime() * 3)
	elseif self:GetBlock() then
		ghostlerp1 = math.min(1, ghostlerp1 + FrameTime() * 2)
	end

	if ghostlerp > 0 then
		pos = pos + 3.5 * ghostlerp * ang:Up()
		ang:RotateAroundAxis(ang:Right(), -30 * ghostlerp)
	end
	if ghostlerp1 > 0 then
		pos = pos - 3.5 * ghostlerp1 * ang:Up()
		ang:RotateAroundAxis(ang:Right(), 20 * ghostlerp1)
		ang:RotateAroundAxis(ang:Forward(), 20 * ghostlerp1)
	end

	return pos, ang
end
