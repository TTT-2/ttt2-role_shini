if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_shini.vmt")
end

function ROLE:PreInitialize()
	self.color = Color(200, 200, 200, 255)

	self.abbr = "shini" -- abbreviation
	self.surviveBonus = 0.5 -- bonus multiplier for every survive while another player was killed
	self.scoreKillsMultiplier = 1 -- multiplier for kill of player of another team
	self.scoreTeamKillsMultiplier = -8 -- multiplier for teamkill
	self.unknownTeam = true -- disable team voice chat
	self.disableSync = true -- dont tell the player about his role
	self.defaultTeam = TEAM_INNOCENT -- the team name: roles with same team name are working together
	self.defaultEquipment = INNO_EQUIPMENT -- here you can set up your own default equipment

	self.conVarData = {
		pct = 0.15, -- necessary: percentage of getting this role selected (per player)
		maximum = 1, -- maximum amount of roles in a round
		minPlayers = 6, -- minimum amount of players until this role is able to get selected
		credits = 0, -- the starting credits of a specific role
		togglable = false, -- option to toggle a role for a client if possible (F1 menu)
		random = 50
	}
end

function ROLE:Initialize()
	roles.SetBaseRole(self, ROLE_INNOCENT)
end

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicNecroCVars", function(tbl)
	tbl[ROLE_SHINIGAMI] = tbl[ROLE_SHINIGAMI] or {}

	table.insert(tbl[ROLE_SHINIGAMI], {cvar = "ttt2_shinigami_speed", slider = true, min = 0, max = 5, decimal = 2, desc = "Shinigami speed multiplier (Def: 2.00)"})
	table.insert(tbl[ROLE_SHINIGAMI], {cvar = "ttt2_shinigami_health_loss", slider = true, min = 0, max = 100, decimal = 0, desc = "DPS for the Shinigami, when respawned (Def: 5)"})
end)

if SERVER then
	local shini_speed = CreateConVar("ttt2_shinigami_speed", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The speed the shinigami has when he respawns (Def: 2)")
	local shini_health_loss = CreateConVar("ttt2_shinigami_health_loss", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The amount of damage the shinigami receives every second after he respawns (Def: 5)")

	local function ResetShinigami()
		for _, ply in ipairs(player.GetAll()) do
			ply:SetNWBool("SpawnedAsShinigami", false)
		end
	end

	hook.Add("TTT2SyncGlobals", "AddShinigamiGlobals", function()
		SetGlobalFloat(shini_speed:GetName(), shini_speed:GetFloat())
		SetGlobalFloat(shini_health_loss:GetName(), shini_health_loss:GetFloat())
	end)

	cvars.AddChangeCallback(shini_speed:GetName(), function(name, old, new)
		SetGlobalFloat(name, new)
	end, "TTT2ShiniSpeedChange")

	cvars.AddChangeCallback(shini_health_loss:GetName(), function(name, old, new)
		SetGlobalFloat(name, new)
	end, "TTT2ShiniHealthLossChange")

	hook.Add("TTTEndRound", "ResetShinigami", ResetShinigami)
	hook.Add("TTTPrepareRound", "ResetShinigami", ResetShinigami)
	hook.Add("TTTBeginRound", "ResetShinigami", ResetShinigami)

	hook.Add("TTT2PostPlayerDeath", "OnShinigamiDeath", function(victim, inflictor, attacker)
		if victim:GetSubRole() ~= ROLE_SHINIGAMI or not IsValid(attacker) or not attacker:IsPlayer() or victim == attacker then return end
		if victim:GetSubRole() == ROLE_SHINIGAMI and not victim:GetNWBool("SpawnedAsShinigami") and not victim.reviving and victim:IsGhost( ) == false and attacker:IsGhost( ) == false then
			-- revive after 3s
			victim:Revive(3, function(p) -- this is a TTT2 function that will handle everything else
				p:StripWeapons()
				p:Give("weapon_ttt_shinigamiknife")
				p:SetNWBool("SpawnedAsShinigami", true)
				SendFullStateUpdate()
			end,
			function(p) -- onCheck
				return p:GetSubRole() == ROLE_SHINIGAMI
			end,
			false, true, -- there need to be your corpse and you don't prevent win
			nil)
		end
	end)

	hook.Add("PlayerCanPickupWeapon", "TTTShinigamiPickupWeapon", function(ply, wep)
		if ply:GetSubRole() == ROLE_SHINIGAMI and ply:GetNWBool("SpawnedAsShinigami") and WEPS.GetClass(wep) ~= "weapon_ttt_shinigamiknife" then
			return false
		end
	end)

	hook.Add("Think", "ShinigamiDmgHealth", function()
		for _, v in ipairs(player.GetAll()) do
			local time = CurTime()

			if v:IsActive() and v:IsTerror() and v:GetSubRole() == ROLE_SHINIGAMI and v:GetNWBool("SpawnedAsShinigami") and (v.ShiniLastDamageReceived or 0) + 1 <= time then
				v.ShiniLastDamageReceived = time

				v:TakeDamage(GetGlobalFloat(shini_health_loss:GetName(), 5), game.GetWorld())
			end
		end
	end)

	hook.Add("TTTPlayerSpeedModifier", "ShinigamiModifySpeed", function(ply, _, _, noLag)
		if IsValid(ply) and ply:GetNWBool("SpawnedAsShinigami") and ply:IsGhost( ) == false then
			noLag[1] = noLag[1] * GetGlobalFloat(shini_speed:GetName(), 2)
		end
	end)

	hook.Add("TTT2SpecialRoleSyncing", "TTT2RoleShiniMod", function(ply, tbl)
		-- hide the role from all players
		for shini in pairs(tbl) do
			if shini:GetSubRole() == ROLE_SHINIGAMI and not shini:GetNWBool("SpawnedAsShinigami") then
				tbl[shini] = {ROLE_INNOCENT, TEAM_INNOCENT}
			end
		end

		-- send all traitors to the shinigami
		if ply:GetSubRole() == ROLE_SHINIGAMI and ply:GetNWBool("SpawnedAsShinigami") then
			for p in pairs(tbl) do
				if p:GetTeam() == TEAM_TRAITOR then
					tbl[p] = {p:GetSubRole(), TEAM_TRAITOR}
				end
			end
		end
	end)

	hook.Add("TTT2ModifyRadarRole", "TTT2ModifyRadarRole4Shini", function(ply, target)
		if target:GetSubRole() == ROLE_SHINIGAMI and not target:GetNWBool("SpawnedAsShinigami") then
			return ROLE_INNOCENT
		end
	end)

	hook.Add("TTT2AvoidGeneralChat", "TTT2ModifyGeneralChat4Shini", function(ply, text)
		if not IsValid(ply) or ply:GetSubRole() ~= ROLE_SHINIGAMI or not ply:GetNWBool("SpawnedAsShinigami") then return end

		LANG.Msg(ply, "ttt2_shinigami_chat_jammed", nil, MSG_CHAT_WARN)

		return false
	end)

	hook.Add("TTTOnCorpseCreated", "ModifyShiniRagdoll", function(rag, ply)
		if not IsValid(ply) or not IsValid(rag) or ply:GetSubRole() ~= ROLE_SHINIGAMI or ply:GetNWBool("SpawnedAsShinigami") then return end

		rag.was_role = ROLE_INNOCENT
		rag.role_color = INNOCENT.color

	end)

	-- prevent radio commands
	hook.Add("TTTPlayerRadioCommand", "TTT2ModifyQuickChat4Shini", function()
		return LocalPlayer():GetNWBool("SpawnedAsShinigami", false)
	end)
end

hook.Add("TTT2CanUseVoiceChat", "TTT2ModifyGeneralVoiceChat4Shini", function(speaker, listener)
	if not IsValid(speaker) or not speaker:IsTerror() or speaker:GetSubRole() ~= ROLE_SHINIGAMI or not speaker:GetNWBool("SpawnedAsShinigami") then return end

	return false
end)

hook.Add("TTT2ClientRadioCommand", "TTT2ModifyQuickChat4Shini", function()
	return LocalPlayer():GetNWBool("SpawnedAsShinigami", false)
end)
