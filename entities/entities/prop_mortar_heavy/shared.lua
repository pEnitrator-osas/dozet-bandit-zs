ENT.Type = "anim"
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.SearchDistance = 768
ENT.MinimumAimDot = 0.5
ENT.DefaultAmmo = 3
ENT.MaxAmmo = 5

ENT.PosePitch = 0
ENT.PoseYaw = 0

ENT.m_NoNailUnfreeze = true
ENT.NoNails = true

ENT.CanPackUp = true

ENT.IsBarricadeObject = true
ENT.AlwaysGhostable = true
ENT.MaxUpgrades = 7
ENT.UpgradeCost = 8

local NextCache = 0
local CachedFilter = {}

function ENT:ShouldNotCollide(ent)
	return ent:IsPlayer() and self:GetObjectOwner():IsPlayer() and ent:Team() == self:GetObjectOwner():Team()
end
function ENT:GetMaxAmmo()
	return self.MaxAmmo + self:GetUpgrade()
end

function ENT:GetLocalAnglesToTarget(target)
	return self:WorldToLocalAngles(self:GetAnglesToTarget(target))
end

function ENT:GetAnglesToTarget(target)
	return self:GetAnglesToPos(self:GetTargetPos(target))
end

function ENT:GetLocalAnglesToPos(pos)
	return self:WorldToLocalAngles(self:GetAnglesToPos(pos))
end

function ENT:GetAnglesToPos(pos)
	return (pos - self:ShootPos()):Angle()
end
function ENT:GetUpgrade()
	return self:GetDTInt(12)
end
function ENT:SetUpgrade(upg)
	return self:SetDTInt(12, upg)
end
ENT.MaxShieldCapacity = 250
function ENT:GetShieldDamage()
	return self:GetDTFloat(12)
end
function ENT:SetShieldDamage(dmg)
	return self:SetDTFloat(12, dmg)
end
ENT.BaseDamageST = 85
ENT.WhatUpgradeGive = { ["Урон"] = 12,
["Макс.патрон"] = {1,5},
}

function ENT:IsValidTarget(target)
	if target:IsPlayer() then
		return self:GetObjectOwner():IsPlayer() and target:Team() ~= self:GetObjectOwner():Team() and target:Alive() and self:GetForward():Dot(self:GetAnglesToTarget(target):Forward()) >= self.MinimumAimDot and TrueVisible(self:ShootPos(), self:GetTargetPos(target), self)
	elseif (target:GetClass() == "prop_drone" or target:GetClass() == "prop_manhack") and not target:IsSameTeam(self:GetObjectOwner()) then
		return true
	elseif (target:IsNailed() or target.IsBarricadeObject) and not target:IsSameTeam(self:GetObjectOwner()) and not target:GetClass() == "prop_obj_transmitter" then
		return true
	end
end

local temp_attacker
local temp_attacker_team
local function ManualTraceFilter(ent)
	if ent == temp_attacker or ent:IsPlayer() and ent:Team() == temp_attacker_team then
		return false
	end

	return true
end

local trace_manual = {mask = MASK_SHOT, filter = ManualTraceFilter}
function ENT:GetManualTrace()
	local owner = self:GetObjectOwner()
	local start = self:ShootPos()

	trace_manual.start = start
	trace_manual.endpos = start + owner:GetAimVector() * 4096

	temp_attacker = self
	temp_attacker_team = owner:IsPlayer() and owner:Team() or -1
	return util.TraceLine(trace_manual)
end

function ENT:CalculatePoseAngles()
	local owner = self:GetObjectOwner()
	if not owner:IsValid() or self:GetAmmo() <= 0 or self:GetMaterial() ~= "" or not GAMEMODE:GetWaveActive() then
		self.PoseYaw = math.Approach(self.PoseYaw, 0, FrameTime() * 60)
		self.PosePitch = math.Approach(self.PosePitch, 15, FrameTime() * 30)
		return
	end

	if self:GetManualControl() then
		local ang = self:GetLocalAnglesToPos(self:GetManualTrace().HitPos)
		self.PoseYaw = math.Approach(self.PoseYaw, math.Clamp(math.NormalizeAngle(ang.yaw), -60, 60), FrameTime() * 140)
		self.PosePitch = math.Approach(self.PosePitch, math.Clamp(math.NormalizeAngle(ang.pitch), -15, 15), FrameTime() * 140)
	else
		local target = self:GetTarget()
		if target:IsValid() then
			local ang = self:GetLocalAnglesToTarget(target)
			self.PoseYaw = math.Approach(self.PoseYaw, math.Clamp(math.NormalizeAngle(ang.yaw), -60, 60), FrameTime() * 140)
			self.PosePitch = math.Approach(self.PosePitch, math.Clamp(math.NormalizeAngle(ang.pitch), -15, 15), FrameTime() * 100)
		else
			local ct = CurTime()
			self.PoseYaw = math.Approach(self.PoseYaw, math.sin(ct*1.8) * 75, FrameTime() * 60)
			self.PosePitch = math.Approach(self.PosePitch, math.cos(ct * 3) * 5+5, FrameTime() * 30)
		end
	end
end

function ENT:GetScanFilter()
	local scanteam = nil
	if self:GetObjectOwner():IsPlayer() then scanteam = self:GetObjectOwner():Team() end
	local filter = team.GetPlayers(scanteam)
	filter[#filter + 1] = self
	return filter
end

local NextCache = 0
function ENT:GetCachedScanFilter()
	if CurTime() < NextCache and self.CachedFilter then return self.CachedFilter end

	self.CachedFilter = self:GetScanFilter()
	NextCache = CurTime() + 1

	return self.CachedFilter
end

local tabSearch = {mask = MASK_SHOT}
function ENT:SearchForTarget()
	local shootpos = self:ShootPos()

	tabSearch.start = shootpos
	tabSearch.endpos = shootpos + self:GetGunAngles():Forward() * self.SearchDistance
	tabSearch.filter = self:GetCachedScanFilter()
	local tr = util.TraceLine(tabSearch)
	local ent = tr.Entity
	if ent and ent:IsValid() and self:IsValidTarget(ent) then
		return ent
	end
end

function ENT:GetTargetPos(target)
		local boneid = target:GetHitBoxBone(HITGROUP_HEAD, 0)
		if boneid and boneid > 0 then
			local p, a = target:GetBonePosition(boneid)
			if pl then
				return p
			end
		end

	return target:LocalToWorld(target:OBBCenter())
end

function ENT:HumanHoldable(pl)
	return true
end

function ENT:DefaultPos()
	return self:GetPos() + self:GetUp() * 55
end
ENT.WElements = {
	["Turret"] = { type = "Model", model = "models/Combine_turrets/Floor_turret.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(30.177, 0, 38.969), angle = Angle(0, 0, 180), size = Vector(1, 1, 1), color = Color(255, 255, 255, 0), surpresslightning = false, bonemerge = false, material = "", skin = 0, bodygroup = {} },
	["cannon"] = { type = "Model", model = "models/hunter/tubes/tube4x4x2.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-9.042, 0.24, 23.534), angle = Angle(-30.336, 0, 0), size = Vector(0.068, 0.068, 0.3), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 2, bodygroup = {} },
	["cannon2"] = { type = "Model", model = "models/hunter/misc/shell2x2a.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "cannon", pos = Vector(0, 0, -14.247), angle = Angle(0, -180, 180), size = Vector(0.156, 0.156, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 0, bodygroup = {} },
	["dno_cannon"] = { type = "Model", model = "models/hunter/tubes/circle4x4c.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "cannon", pos = Vector(0, 0, -7.467), angle = Angle(0, 112.946, 0), size = Vector(0.078, 0.078, 4.516), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 0, bodygroup = {} },
	["dno_cannon2"] = { type = "Model", model = "models/hunter/tubes/circle4x4c.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "cannon", pos = Vector(0, 0, -7.467), angle = Angle(0, -67.213, 0), size = Vector(0.078, 0.078, 4.516), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 0, bodygroup = {} },
	["end_cannon"] = { type = "Model", model = "models/props_phx/construct/metal_wire_angle360x2.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "cannon", pos = Vector(0, 0, 0.726), angle = Angle(0, 0, 0), size = Vector(0.146, 0.146, 0.146), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "", skin = 0, bodygroup = {} },
	["end_cannon2"] = { type = "Model", model = "models/hunter/tubes/tube4x4x2to2x2.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "cannon", pos = Vector(0, 0, 14.454), angle = Angle(0, 180, 180), size = Vector(0.092, 0.092, 0.092), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 0, bodygroup = {} },
	["end_cannon3"] = { type = "Model", model = "models/hunter/tubes/circle4x4.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "cannon", pos = Vector(0, 0, 13.023), angle = Angle(0, 0, 0), size = Vector(0.067, 0.067, 0.067), color = Color(27, 27, 27, 255), surpresslightning = false, bonemerge = false, material = "metal/metalhull010b", skin = 0, bodygroup = {} },
	["end_cannon4"] = { type = "Model", model = "models/props_phx/construct/metal_wire_angle360x2.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "cannon", pos = Vector(0, 0, 0.726), angle = Angle(0, 9.138, 0), size = Vector(0.146, 0.146, 0.146), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "", skin = 0, bodygroup = {} },
	["osnova"] = { type = "Model", model = "models/props_phx/construct/metal_angle360.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(0, 0, 5), angle = Angle(0, 0, 0), size = Vector(0.497, 0.497, 0.497), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 0, bodygroup = {} },
	["osnova+"] = { type = "Model", model = "models/props_phx/construct/metal_angle360.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(0, 0, 0), angle = Angle(0, 0, 0), size = Vector(0.65, 0.65, 0.65), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "metal/metalcombine002", skin = 0, bodygroup = {} },
	["osnova2"] = { type = "Model", model = "models/Mechanics/gears2/vert_18t1.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(0, 0, 5.349), angle = Angle(0, 0, 0), size = Vector(1.286, 1.286, 1), color = Color(255, 0, 0, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 0, bodygroup = {} },
	["osnova3"] = { type = "Model", model = "models/Mechanics/gears2/vert_18t1.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(0, 0, 5.349), angle = Angle(0, -9.613, 0), size = Vector(1.286, 1.286, 1.011), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/concrete1", skin = 0, bodygroup = {} },
	["regular"] = { type = "Model", model = "models/props_phx/trains/monorail_curve.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-20.467, 12.122, 4.442), angle = Angle(-81, -180, 90), size = Vector(0.037, 0.039, 0.2), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/iron_rails", skin = 0, bodygroup = {} },
	["regular2"] = { type = "Model", model = "models/props_phx/trains/monorail_curve.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-20.468, -6.092, 4.442), angle = Angle(-81, -180, 90), size = Vector(0.037, 0.039, 0.2), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/iron_rails", skin = 0, bodygroup = {} },
	["regular4"] = { type = "Model", model = "models/props_borealis/door_wheel001a.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-6.837, 11.68, 21.97), angle = Angle(0, -90, 0), size = Vector(1.069, 0.423, 0.423), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "", skin = 0, bodygroup = {} },
	["regular5"] = { type = "Model", model = "models/hunter/blocks/cube025x2x025.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-11.962, -7.266, 15.729), angle = Angle(0, 0, -90), size = Vector(0.25, 0.211, 0.25), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/iron_rails", skin = 0, bodygroup = {} },
	["regular6"] = { type = "Model", model = "models/hunter/blocks/cube025x2x025.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-11.962, 10.92, 15.728), angle = Angle(0, 0, -90), size = Vector(0.25, 0.211, 0.25), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/iron_rails", skin = 0, bodygroup = {} },
	["second regular"] = { type = "Model", model = "models/hunter/geometric/hex05x1.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-15.586, 8.696, 6.436), angle = Angle(-90, 90, 0), size = Vector(0.13, 0.13, 0.5), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/iron_rails", skin = 0, bodygroup = {} },
	["second regular2"] = { type = "Model", model = "models/hunter/geometric/hex05x1.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "Turret", pos = Vector(-15.587, -6.719, 6.435), angle = Angle(-90, 90, 0), size = Vector(0.13, 0.13, 0.5), color = Color(255, 255, 255, 255), surpresslightning = false, bonemerge = false, material = "phoenix_storms/iron_rails", skin = 0, bodygroup = {} }
}
function ENT:ShootPos()
	local attachid = self.WElements['cannon'].modelEnt
	if attachid then
		return attachid:GetPos()
	end
	return self:DefaultPos()
end

function ENT:LaserPos()
	local attachid = self.WElements['cannon'].modelEnt
	if attachid then
		return attachid:GetPos()
	end
	return self:DefaultPos()
end
ENT.LightPos = ENT.LaserPos

function ENT:GetGunAngles()
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ang:Right(), -self.PosePitch)
	ang:RotateAroundAxis(ang:Up(), self.PoseYaw)
	return ang
end

function ENT:SetAmmo(ammo)
	self:SetDTInt(0, math.min(ammo,self:GetMaxAmmo()))
end

function ENT:GetAmmo()
	return self:GetDTInt(0)
end

function ENT:SetTarget(ent)
	if ent:IsValid() then
		self:SetTargetReceived(CurTime())
		if SERVER then
			self.LastHitSomething = CurTime()
		end
	else
		self:SetTargetLost(CurTime())
	end
	self:SetDTEntity(0, ent)
end

function ENT:GetObjectHealth()
	return self:GetDTFloat(3)
end

function ENT:SetMaxObjectHealth(health)
	self:SetDTInt(1, health)
end

function ENT:GetMaxObjectHealth()
	return self:GetDTInt(1)
end

function ENT:GetTarget()
	return self:GetDTEntity(0)
end

function ENT:SetObjectOwner(ent)
	self:SetDTEntity(1, ent)
end

function ENT:GetObjectOwner()
	return self:GetDTEntity(1)
end

function ENT:ClearObjectOwner()
	self:SetObjectOwner(NULL)
end

function ENT:ClearTarget()
	self:SetTarget(NULL)
end

function ENT:SetTargetReceived(tim)
	self:SetDTFloat(0, tim)
end

function ENT:GetTargetReceived()
	return self:GetDTFloat(0)
end

function ENT:SetTargetLost(tim)
	self:SetDTFloat(1, tim)
end

function ENT:GetTargetLost()
	return self:GetDTFloat(1)
end

function ENT:SetNextFire(tim)
	self:SetDTFloat(2, tim)
end

function ENT:GetNextFire()
	return self:GetDTFloat(2)
end

function ENT:SetFiring(onoff)
	self:SetDTBool(0, onoff)
end

function ENT:IsFiring()
	return self:GetDTBool(0)
end

function ENT:GetManualControl()
	local owner = self:GetObjectOwner()
	if owner:IsValid() and owner:Alive() and (owner:Team() == TEAM_HUMAN or owner:Team() == TEAM_BANDIT) then
		local wep = owner:GetActiveWeapon()
		if wep:IsValid() and wep:GetClass() == "weapon_zs_gunturretcontrol" and not wep:GetDTBool(0) then
			return true
		end
	end
	return false
end

function ENT:CanBePackedBy(pl)
	local owner = self:GetObjectOwner()
	if not pl:IsPlayer() or not owner:IsPlayer() then return false end
	return not owner:IsValid() or owner == pl or owner:Team() == pl:Team() or gamemode.Call("PlayerIsAdmin", pl)
end


util.PrecacheSound("npc/turret_floor/die.wav")
util.PrecacheSound("npc/turret_floor/active.wav")
util.PrecacheSound("npc/turret_floor/deploy.wav")
util.PrecacheSound("npc/turret_floor/shoot1.wav")
util.PrecacheSound("npc/turret_floor/shoot2.wav")
util.PrecacheSound("npc/turret_floor/shoot3.wav")
