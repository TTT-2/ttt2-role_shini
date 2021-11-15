if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_shini.vmt")
end

function ROLE:PreInitialize()
	self.color = Color(200, 200, 200, 255)

	self.abbr = "shini"
	self.score.killsMultiplier = 2
	self.score.teamKillsMultiplier = -8
	self.unknownTeam = true
	self.disableSync = true

	self.defaultTeam = TEAM_INNOCENT
	self.defaultEquipment = INNO_EQUIPMENT

	self.conVarData = {
		pct = 0.15,
		maximum = 1,
		minPlayers = 6,
		credits = 0,
		togglable = false,
		random = 50
	}
end

function ROLE:Initialize()
	roles.SetBaseRole(self, ROLE_INNOCENT)
end

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicShiniCVars", function(tbl)
	tbl[ROLE_SHINIGAMI] = tbl[ROLE_SHINIGAMI] or {}

	table.insert(tbl[ROLE_SHINIGAMI], {
		cvar = "ttt2_shinigami_speed",
		slider = true,
		min = 0,
		max = 5,
		decimal = 2,
		desc = "Shinigami speed multiplier (Def: 2.00)"}
	)

	table.insert(tbl[ROLE_SHINIGAMI], {
		cvar = "ttt2_shinigami_health_loss",
		slider = true,
		min = 0,
		max = 100,
		decimal = 0,
		desc = "DPS for the Shinigami, when respawned (Def: 5)"}
	)
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
		if victim:GetSubRole() == ROLE_SHINIGAMI and not victim:GetNWBool("SpawnedAsShinigami") and not victim.reviving then
			-- revive after 3s
			victim:Revive(3,
				function(p) -- this is a TTT2 function that will handle everything else
					-- reset confirm Shini player, in case their body was confirmed
					p:ResetConfirmPlayer()

					p:StripWeapons()
					p:Give("weapon_ttt_shinigamiknife")
					p:SetNWBool("SpawnedAsShinigami", true)

					SendFullStateUpdate()
				end,
				function(p) -- onCheck
					return p:GetSubRole() == ROLE_SHINIGAMI
				end,
				false, REVIVAL_BLOCK_AS_ALIVE, -- there need to be the corpse and the round end has to be prevented
				nil
			)

			victim:SendRevivalReason("ttt2_shinigami_revive")
		end
	end)

	hook.Add("PlayerCanPickupWeapon", "TTTShinigamiPickupWeapon", function(ply, wep)
		if SpecDM and (ply.IsGhost and ply:IsGhost()) then return end
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

	hook.Add("TTT2SpecialRoleSyncing", "TTT2RoleShiniMod", function(ply, tbl)
		-- hide the role from all players
		for shini in pairs(tbl) do
			if shini:GetSubRole() ~= ROLE_SHINIGAMI or shini:GetNWBool("SpawnedAsShinigami") then continue end

			if shini == ply then -- show inno to the shini itself
				tbl[shini] = {ROLE_INNOCENT, TEAM_INNOCENT}
			else
				tbl[shini] = {ROLE_NONE, TEAM_NONE} -- sync none to other players
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
	hook.Add("TTTPlayerRadioCommand", "TTT2ModifyQuickChat4Shini", function(ply, msg_name, msg_target)
		if ply:GetNWBool("SpawnedAsShinigami", false) then
			return true
		end
	end)
end

hook.Add("TTTPlayerSpeedModifier", "ShinigamiModifySpeed", function(ply, _, _, noLag)
	if not IsValid(ply) or not ply:GetNWBool("SpawnedAsShinigami") or ply:GetSubRole() ~= ROLE_SHINIGAMI then return end

	noLag[1] = noLag[1] * GetGlobalFloat("ttt2_shinigami_speed", 2)
end)

hook.Add("TTT2CanUseVoiceChat", "TTT2ModifyGeneralVoiceChat4Shini", function(speaker, listener)
	if not IsValid(speaker) or not speaker:IsTerror() or speaker:GetSubRole() ~= ROLE_SHINIGAMI or not speaker:GetNWBool("SpawnedAsShinigami") then return end

	return false
end)

hook.Add("TTT2ClientRadioCommand", "TTT2ModifyQuickChat4Shini", function()
	if LocalPlayer():GetNWBool("SpawnedAsShinigami", false) then
		return true
	end
end)
