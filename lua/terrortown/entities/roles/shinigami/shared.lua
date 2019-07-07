if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_shini.vmt")
end

ROLE.color = Color(200, 200, 200, 255) -- ...
ROLE.dkcolor = Color(180, 180, 180, 255) -- ...
ROLE.bgcolor = Color(200, 68, 81, 255) -- ...
ROLE.abbr = "shini" -- abbreviation
ROLE.defaultTeam = TEAM_INNOCENT -- the team name: roles with same team name are working together
ROLE.defaultEquipment = INNO_EQUIPMENT -- here you can set up your own default equipment
ROLE.surviveBonus = 0.5 -- bonus multiplier for every survive while another player was killed
ROLE.scoreKillsMultiplier = 1 -- multiplier for kill of player of another team
ROLE.scoreTeamKillsMultiplier = -8 -- multiplier for teamkill
ROLE.unknownTeam = true -- disable team voice chat
ROLE.disableSync = true -- dont tell the player about his role

ROLE.conVarData = {
	pct = 0.15, -- necessary: percentage of getting this role selected (per player)
	maximum = 1, -- maximum amount of roles in a round
	minPlayers = 6, -- minimum amount of players until this role is able to get selected
	credits = 0, -- the starting credits of a specific role
	togglable = false, -- option to toggle a role for a client if possible (F1 menu)
	random = 50
}

-- now link this subrole with its baserole
hook.Add("TTT2BaseRoleInit", "TTT2ConBRTWithShini", function()
	SHINIGAMI:SetBaseRole(ROLE_INNOCENT)
end)

hook.Add("TTT2RolesLoaded", "AddShinigamiTeam", function()
	SHINIGAMI.defaultTeam = TEAM_INNOCENT
end)

-- if sync of roles has finished
hook.Add("TTT2FinishedLoading", "ShinigamiInitT", function()
	if CLIENT then
		-- setup here is not necessary but if you want to access the role data, you need to start here
		-- setup basic translation !
		LANG.AddToLanguage("English", SHINIGAMI.name, "Shinigami")
		LANG.AddToLanguage("English", "info_popup_" .. SHINIGAMI.name, [[You are a Shinigami! Try to kill the evil terrorists!]])
		LANG.AddToLanguage("English", "body_found_" .. SHINIGAMI.abbr, "They were a Shinigami.")
		LANG.AddToLanguage("English", "search_role_" .. SHINIGAMI.abbr, "This person was a Shinigami!")
		LANG.AddToLanguage("English", "target_" .. SHINIGAMI.name, "Shinigami")
		LANG.AddToLanguage("English", "ttt2_desc_" .. SHINIGAMI.name, [[The Shinigami is an Innocent (who works together with the other innocents) and the goal is to kill all evil roles ^^ The Shinigami is able to see the names of his enemies.]])

		---------------------------------

		-- maybe this language as well...
		LANG.AddToLanguage("Deutsch", SHINIGAMI.name, "Shinigami")
		LANG.AddToLanguage("Deutsch", "info_popup_" .. SHINIGAMI.name, [[Du bist ein Shinigami! Versuche die Bösen zu töten!]])
		LANG.AddToLanguage("Deutsch", "body_found_" .. SHINIGAMI.abbr, "Er war ein Shinigami.")
		LANG.AddToLanguage("Deutsch", "search_role_" .. SHINIGAMI.abbr, "Diese Person war ein Shinigami!")
		LANG.AddToLanguage("Deutsch", "target_" .. SHINIGAMI.name, "Shinigami")
		LANG.AddToLanguage("Deutsch", "ttt2_desc_" .. SHINIGAMI.name, [[Der Shinigami ist ein Innocent (der mit den anderen Innocent-Rollen zusammenarbeitet) und dessen Ziel es ist, alle bösen Rollen zu töten ^^ Er kann die Namen seiner Feinde sehen.]])
	end
end)

if SERVER then
	local shini_speed = CreateConVar("ttt2_shinigami_speed", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The speed the shinigami has when he respawns (Def: 2)")
	local shini_health_loss = CreateConVar("ttt2_shinigami_health_loss", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The amount of damage the shinigami receives every second after he respawns (Def: 5)")

	local function ResetShinigami()
		for _, ply in ipairs(player.GetAll()) do
			ply.SpawnedAsShinigami = nil
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
		if victim:IsShinigami() and not victim.SpawnedAsShinigami and not victim.reviving then
			-- revive after 3s
			victim:Revive(3, function(p) -- this is a TTT2 function that will handle everything else
				p:StripWeapons()
				p:Give("weapon_ttt_shinigamiknife")
				p.SpawnedAsShinigami = CurTime()
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
		if ply.SpawnedAsShinigami and WEPS.GetClass(wep) ~= "weapon_ttt_shinigamiknife" then
			return false
		end
	end)

	hook.Add("Think", "ShinigamiDmgHealth", function()
		for _, v in ipairs(player.GetAll()) do
			local time = CurTime()

			if v.SpawnedAsShinigami and v.SpawnedAsShinigami + 1 <= time then
				v.SpawnedAsShinigami = time + 1

				v:TakeDamage(GetGlobalFloat(shini_health_loss:GetName(), 5), game.GetWorld())
			end
		end
	end)

	hook.Add("TTTPlayerSpeedModifier", "ShinigamiModifySpeed", function(ply, _, _, noLag)
		if IsValid(ply) and ply.SpawnedAsShinigami then
			noLag[1] = noLag[1] * GetGlobalFloat(shini_speed:GetName(), 2)
		end
	end)

	hook.Add("TTT2SpecialRoleSyncing", "TTT2RoleShiniMod", function(ply, tbl)
		-- hide the role from all players
		for shini in pairs(tbl) do
			if shini:IsShinigami() and not shini.SpawnedAsShinigami then
				tbl[shini] = {ROLE_INNOCENT, TEAM_INNOCENT}
			end
		end

		-- send all traitors to the shinigami
		if ply:IsShinigami() and ply.SpawnedAsShinigami then
			for p in pairs(tbl) do
				if p:GetTeam() == TEAM_TRAITOR then
					tbl[p] = {p:GetSubRole(), TEAM_TRAITOR}
				end
			end
		end
	end)

	hook.Add("TTT2ModifyRadarRole", "TTT2ModifyRadarRole4Shini", function(ply, target)
		if target:IsShinigami() and not target.SpawnedAsShinigami then
			return ROLE_INNOCENT
		end
	end)

end
