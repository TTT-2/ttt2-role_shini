if CLIENT then
	-- Role functions
	function ROLE:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_roles_additional")

		form:MakeCheckBox({
		serverConvar = "ttt2_shini_needs_corpse",
		label = "label_shinigami_needs_corpse"
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_shini_allow_key_respawn",
			label = "label_shinigami_allow_key_respawn"
		})

		form:MakeSlider({
			serverConvar = "ttt2_shini_revive_time",
			label = "label_shinigami_revive_time",
			min = 0,
			max = 10,
			decimal = 0
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_shinigami_announcement",
			label = "label_shinigami_announcement"
		})

		form:MakeSlider({
			serverConvar = "ttt2_shinigami_speed",
			label = "label_shinigami_speed",
			min = 0,
			max = 5,
			decimal = 2
		})

		form:MakeSlider({
			serverConvar = "ttt2_shinigami_health_loss",
			label = "label_shinigami_health_loss",
			min = 0,
			max = 100,
			decimal = 0
		})
	end

	-- Hooks
	hook.Add("Initialize", "TTT_Shini_KeyBinds", function()
		-- Register keybinds

		bind.Register("ttt_shini_respawn_corpse", function()
			net.Start("ttt_shini_key_respawn")
			net.WriteBool(true)
			net.SendToServer()
		end, nil, "Roles", "Shinigami - Respawn at corpse", corpseKey or KEY_R)

		bind.Register("ttt_shini_respawn_spawn", function()
			net.Start("ttt_shini_key_respawn")
			net.WriteBool(false)
			net.SendToServer()
		end, nil, "Roles", "Shinigami - Respawn at spawn", spawnKey or KEY_SPACE)
	end)

	-- Network listeners
	net.Receive("ttt_shini_show_reason", function(len, ply)
		-- Get strings for keybinds, this is the same logic as in the addon "A Second Chance"
		corpseKey = bind.Find("ttt_shini_respawn_corpse") == KEY_NONE and "NONE" or string.upper(input.GetKeyName(bind.Find("ttt_shini_respawn_corpse")))
		spawnKey = bind.Find("ttt_shini_respawn_spawn") == KEY_NONE and "NONE" or string.upper(input.GetKeyName(bind.Find("ttt_shini_respawn_spawn")))

		LocalPlayer():SetRevivalReason("ttt2_shinigami_revive_keys", {keycorpse = corpseKey, keyspawn = spawnKey})
	end)
elseif SERVER then
	-- Init
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_shini.vmt")

	-- NetworkStrings
	util.AddNetworkString("ttt_shini_key_respawn")
	util.AddNetworkString("ttt_shini_show_reason")

	-- ConVars
	local shini_announcement = CreateConVar("ttt2_shinigami_announcement", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Announce the shinigami being respawned (Def: 0)")
	local shini_speed = CreateConVar("ttt2_shinigami_speed", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The speed the shinigami has when he respawns (Def: 2)")
	local shini_health_loss = CreateConVar("ttt2_shinigami_health_loss", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The amount of damage the shinigami receives every second after he respawns (Def: 5)")
	local shini_needs_corpse = CreateConVar("ttt2_shini_needs_corpse", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "If the shinigami needs a corpse to revive (Def: 0)")
	local shini_allow_key_respawn = CreateConVar("ttt2_shini_allow_key_respawn", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "If the shinigami is able to select where to respawn (Def: 1)")
	local shini_revive_time = CreateConVar("ttt2_shini_revive_time", 3, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "The time it takes for the shinigami to revive (Def: 3)", 0, 10)

	-- ConVar Callbacks
	cvars.AddChangeCallback(shini_speed:GetName(), function(name, old, new)
		SetGlobalFloat(name, new)
	end, "TTT2ShiniSpeedChange")

	cvars.AddChangeCallback(shini_health_loss:GetName(), function(name, old, new)
		SetGlobalFloat(name, new)
	end, "TTT2ShiniHealthLossChange")

	-- Util functions
	local function SpawnAsShinigami(ply)
		-- reset confirm Shini player, in case their body was confirmed
		ply:ResetConfirmPlayer()

		ply:StripWeapons()
		ply:GiveEquipmentWeapon("weapon_ttt_shinigamiknife")
		ply:SetNWBool("SpawnedAsShinigami", true)

		SendFullStateUpdate()

		-- NOTIFY ALL PLAYERS THAT THE SHINIGAMI HAS RESPAWNED
		if shini_announcement:GetBool() then
			LANG.MsgAll("ttt2_role_shinigami_info_spawned", nil, MSG_MSTACK_WARN)
		end
	end

	local function ResetShinigami()
		for _, ply in ipairs(player.GetAll()) do
			ply:SetNWBool("SpawnedAsShinigami", false)
		end
	end

	-- Network listeners
	net.Receive("ttt_shini_key_respawn", function(len, ply)
		-- Only run this function if the player is alive,
		-- the ConVar is enabled and the player is not already a revived Shinigami
		if not IsValid(ply) or ply:IsTerror() or shini_allow_key_respawn:GetBool() ~= true then return end
		if ply:GetNWBool("SpawnedAsShinigami", false) or ply:GetSubRole() ~= ROLE_SHINIGAMI then return end

		local respawnAtCorpse = net.ReadBool()
		local spawnPosition = {pos = nil, ang = nil}

		if not respawnAtCorpse then
			spawnPosition = plyspawn.GetRandomSafePlayerSpawnPoint(ply)
		end

		ply:CancelRevival(nil, true)
		ply:SendRevivalReason(nil)

		ply:Revive(
			0, -- reviveTime
			SpawnAsShinigami,
			nil, -- doCheck
			shini_needs_corpse:GetBool(), -- needsCorpse
			REVIVAL_BLOCK_AS_ALIVE, -- blockRound
			nil, -- onFail
			spawnPosition.pos, -- spawnPos
			spawnPosition.ang -- spawnEyeAngle
		)
	end)

	-- Hooks
	hook.Add("TTT2SyncGlobals", "AddShinigamiGlobals", function()
		SetGlobalFloat(shini_speed:GetName(), shini_speed:GetFloat())
		SetGlobalFloat(shini_health_loss:GetName(), shini_health_loss:GetFloat())
	end)

	hook.Add("TTTEndRound", "ResetShinigami", ResetShinigami)
	hook.Add("TTTPrepareRound", "ResetShinigami", ResetShinigami)
	hook.Add("TTTBeginRound", "ResetShinigami", ResetShinigami)
	hook.Add("TTT2UpdateSubrole", "ResetShinigami", function(ply, oldSubRole, newSubRole)
		ply:SetNWBool("SpawnedAsShinigami", false)
	end)

	hook.Add("TTT2PostPlayerDeath", "OnShinigamiDeath", function(victim, inflictor, attacker)
		if victim:GetSubRole() == ROLE_SHINIGAMI and not victim:GetNWBool("SpawnedAsShinigami") and not victim.reviving then
			-- revive after specified time
			victim:Revive(
				shini_revive_time:GetInt(),
				SpawnAsShinigami,
				function(p) -- onCheck
					return p:GetSubRole() == ROLE_SHINIGAMI
				end,
				shini_needs_corpse:GetBool(),
				REVIVAL_BLOCK_AS_ALIVE, -- there need to be the corpse and the round end has to be prevented
				nil
			)

			-- Tell the client to show keybinds if player is able to select spawn
			if shini_allow_key_respawn:GetBool() == true then
				net.Start("ttt_shini_show_reason")
				net.Send(victim)
			else
				victim:SendRevivalReason("ttt2_shinigami_revive")
			end
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

	hook.Add("TTTLastWordsMsg", "TTT2ModifyLastWords4Shini", function(ply, msg, msgOriginal)
		if not IsValid(ply) or ply:GetSubRole() ~= ROLE_SHINIGAMI or not ply:GetNWBool("SpawnedAsShinigami") then return end

		return true
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

-- Shared

-- Role functions
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

function ROLE:RemoveRoleLoadout(ply, isRoleChange)
	-- give back normal player loadout
	ply:GiveEquipmentWeapon("weapon_zm_improvised")
	ply:GiveEquipmentWeapon("weapon_zm_carry")
	ply:GiveEquipmentWeapon("weapon_ttt_unarmed")

	ply:StripWeapon("weapon_ttt_shinigamiknife")
end

-- Hooks
hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicShiniCVars", function(tbl)
	tbl[ROLE_SHINIGAMI] = tbl[ROLE_SHINIGAMI] or {}

	table.insert(tbl[ROLE_SHINIGAMI], {
		cvar = "ttt2_shinigami_announcement",
		checkbox = true,
		desc = "Announce when a shinigami is being respawned (Def. 0)"
	})

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
