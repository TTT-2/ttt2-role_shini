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

	if CLIENT then
		-- Role specific language elements
		LANG.AddToLanguage("English", self.name, "Shinigami")
		LANG.AddToLanguage("English", "info_popup_" .. self.name, [[You are a Shinigami! Try to kill the evil terrorists!]])
		LANG.AddToLanguage("English", "body_found_" .. self.abbr, "They were a Shinigami.")
		LANG.AddToLanguage("English", "search_role_" .. self.abbr, "This person was a Shinigami!")
		LANG.AddToLanguage("English", "target_" .. self.name, "Shinigami")
		LANG.AddToLanguage("English", "ttt2_desc_" .. self.name, [[The Shinigami is an Innocent (who works together with the other innocents) and the goal is to kill all evil roles ^^ The Shinigami is able to see the names of his enemies.]])

		LANG.AddToLanguage("Deutsch", self.name, "Shinigami")
		LANG.AddToLanguage("Deutsch", "info_popup_" .. self.name, [[Du bist ein Shinigami! Versuche die Bösen zu töten!]])
		LANG.AddToLanguage("Deutsch", "body_found_" .. self.abbr, "Er war ein Shinigami.")
		LANG.AddToLanguage("Deutsch", "search_role_" .. self.abbr, "Diese Person war ein Shinigami!")
		LANG.AddToLanguage("Deutsch", "target_" .. self.name, "Shinigami")
		LANG.AddToLanguage("Deutsch", "ttt2_desc_" .. self.name, [[Der Shinigami ist ein Innocent (der mit den anderen Innocent-Rollen zusammenarbeitet) und dessen Ziel es ist, alle bösen Rollen zu töten ^^ Er kann die Namen seiner Feinde sehen.]])

		-- additional lang strings
		LANG.AddToLanguage("English", "ttt2_shinigami_chat_jammed", "The Chat is jammed! You can't use the chat as a respawned Shinigami.")
		LANG.AddToLanguage("Deutsch", "ttt2_shinigami_chat_jammed", "Der Chat ist blockiert! Du kannst den Chat als ein neu Gespawnter Shinigami nicht verwenden.")
	end
end

if SERVER then
	local shini_speed = CreateConVar("ttt2_shinigami_speed", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The speed the shinigami has when he respawns (Def: 2)")
	local shini_health_loss = CreateConVar("ttt2_shinigami_health_loss", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The amount of damage the shinigami receives every second after he respawns (Def: 5)")

	local function ResetShinigami()
		for _, ply in ipairs(player.GetAll()) do
			ply:SetNWFloat("SpawnedAsShinigami", -1)
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
		if victim:IsShinigami() and victim:GetNWBool("SpawnedAsShinigami", -1) == -1 and not victim.reviving then
			-- revive after 3s
			victim:Revive(3, function(p) -- this is a TTT2 function that will handle everything else
				p:StripWeapons()
				p:Give("weapon_ttt_shinigamiknife")
				p:SetNWFloat("SpawnedAsShinigami", CurTime())
				SendFullStateUpdate()
			end,
			function(p) -- onCheck
				return p:IsShinigami()
			end,
			false, true, -- there need to be your corpse and you don't prevent win
			nil)
		end
	end)

	hook.Add("PlayerCanPickupWeapon", "TTTShinigamiPickupWeapon", function(ply, wep)
		if ply:GetNWBool("SpawnedAsShinigami", -1) ~= -1 and WEPS.GetClass(wep) ~= "weapon_ttt_shinigamiknife" then
			return false
		end
	end)

	hook.Add("Think", "ShinigamiDmgHealth", function()
		for _, v in ipairs(player.GetAll()) do
			local time = CurTime()

			if v:GetNWBool("SpawnedAsShinigami", -1) ~= -1 and v:GetNWBool("SpawnedAsShinigami", -1) + 1 <= time then
				v:SetNWFloat("SpawnedAsShinigami", time + 1)

				v:TakeDamage(GetGlobalFloat(shini_health_loss:GetName(), 5), game.GetWorld())
			end
		end
	end)

	hook.Add("TTTPlayerSpeedModifier", "ShinigamiModifySpeed", function(ply, _, _, noLag)
		if IsValid(ply) and ply:GetNWBool("SpawnedAsShinigami", -1) ~= -1 then
			noLag[1] = noLag[1] * GetGlobalFloat(shini_speed:GetName(), 2)
		end
	end)

	hook.Add("TTT2SpecialRoleSyncing", "TTT2RoleShiniMod", function(ply, tbl)
		-- hide the role from all players
		for shini in pairs(tbl) do
			if shini:IsShinigami() and shini:GetNWBool("SpawnedAsShinigami", -1) == -1 then
				tbl[shini] = {ROLE_INNOCENT, TEAM_INNOCENT}
			end
		end

		-- send all traitors to the shinigami
		if ply:IsShinigami() and ply:GetNWBool("SpawnedAsShinigami", -1) ~= -1 then
			for p in pairs(tbl) do
				if p:GetTeam() == TEAM_TRAITOR then
					tbl[p] = {p:GetSubRole(), TEAM_TRAITOR}
				end
			end
		end
	end)

	hook.Add("TTT2ModifyRadarRole", "TTT2ModifyRadarRole4Shini", function(ply, target)
		if target:IsShinigami() and target:GetNWBool("SpawnedAsShinigami", -1) == -1 then
			return ROLE_INNOCENT
		end
	end)

	hook.Add("TTT2AvoidGeneralChat", "TTT2ModifyGeneralChat4Shini", function(ply, text)
		if not IsValid(ply) then return end

		if ply:GetSubRole() ~= ROLE_SHINIGAMI then return end

		if ply:GetNWBool("SpawnedAsShinigami", -1) == -1 then return end

		LANG.Msg(ply, "ttt2_shinigami_chat_jammed", nil, MSG_CHAT_WARN)

		return false
	end)
end

hook.Add("TTT2CanUseVoiceChat", "TTT2ModifyGeneralVoiceChat4Shini", function(speaker, listener)
	if not IsValid(speaker) then return end

	if speaker:GetSubRole() ~= ROLE_SHINIGAMI then return end

	if speaker:GetNWBool("SpawnedAsShinigami", -1) == -1 then return end

	return false
end)
