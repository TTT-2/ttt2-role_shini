AddCSLuaFile()

SWEP.HoldType = "knife"

if CLIENT then
	SWEP.PrintName = "Shinigami's Knife"
	SWEP.Slot = 8

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54
	SWEP.DrawCrosshair = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "knife_desc"
	}

	SWEP.Icon = "vgui/ttt/icon_knife"
	SWEP.IconLetter = "j"
end

SWEP.Base = "weapon_tttbase"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"

SWEP.Primary.Damage = 50
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.7
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 1.4

SWEP.Kind = WEAPON_ROLE
SWEP.CanBuy = nil
SWEP.notBuyable = true
SWEP.IsSilent = true
SWEP.AllowDrop = false
SWEP.NoSights = true
SWEP.DeploySpeed = 2

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if not IsValid(self.Owner) then return end

	self.Owner:LagCompensation(true)

	local spos = self.Owner:GetShootPos()
	local sdest = spos + (self.Owner:GetAimVector() * 70)

	local kmins = Vector(1, 1, 1) * -10
	local kmaxs = Vector(1, 1, 1) * 10

	local tr = util.TraceHull({start = spos, endpos = sdest, filter = self.Owner, mask = MASK_SHOT_HULL, mins = kmins, maxs = kmaxs})

	-- Hull might hit environment stuff that line does not hit
	if not IsValid(tr.Entity) then
		tr = util.TraceLine({start = spos, endpos = sdest, filter = self.Owner, mask = MASK_SHOT_HULL})
	end

	local hitEnt = tr.Entity

	-- effects
	if IsValid(hitEnt) then
		self:SendWeaponAnim(ACT_VM_HITCENTER)

		local edata = EffectData()
		edata:SetStart(spos)
		edata:SetOrigin(tr.HitPos)
		edata:SetNormal(tr.Normal)
		edata:SetEntity(hitEnt)

		if hitEnt:IsPlayer() or hitEnt:GetClass() == "prop_ragdoll" then
			util.Effect("BloodImpact", edata)
		end
	else
		self:SendWeaponAnim(ACT_VM_MISSCENTER)
	end

	if SERVER then
		self.Owner:SetAnimation(PLAYER_ATTACK1)
	end


	if SERVER and tr.Hit and tr.HitNonWorld and IsValid(hitEnt) and hitEnt:IsPlayer() then
		local dmg = DamageInfo()
		dmg:SetDamage(self.Primary.Damage)
		dmg:SetAttacker(self.Owner)
		dmg:SetInflictor(self)
		dmg:SetDamageForce(self.Owner:GetAimVector() * 5)
		dmg:SetDamagePosition(self.Owner:GetPos())
		dmg:SetDamageType(DMG_SLASH)

		hitEnt:DispatchTraceAttack(dmg, spos + (self.Owner:GetAimVector() * 3), sdest)
	end

	self.Owner:LagCompensation(false)
end

function SWEP:Equip()
	self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay * 1.5))
	self:SetNextSecondaryFire(CurTime() + (self.Secondary.Delay * 1.5))
end

function SWEP:OnRemove()
	if CLIENT and IsValid(self.Owner) and self.Owner == LocalPlayer() and self.Owner:Alive() then
		RunConsoleCommand("lastinv")
	end
end

function SWEP:OnDrop()
	self:Remove()
end