local base = "base_stacking_element"

DEFINE_BASECLASS(base)

HUDELEMENT.Base = base

if CLIENT then
	local const_defaults = {
							basepos = {x = 0, y = 0},
							size = {w = 321, h = 36},
							minsize = {w = 75, h = 36}
		}

	local element_height = 28
	local margin = 5
	local lpw = 22 -- left panel width

	function HUDELEMENT:PreInitialize()
		self.drawer = hudelements.GetStored("pure_skin_element")
	end

	function HUDELEMENT:Initialize()
		self.scale = 1.0
		self.basecolor = self:GetHUDBasecolor()
		self.element_height = element_height
		self.margin = margin
		self.lpw = lpw

		BaseClass.Initialize(self)
	end

	-- parameter overwrites
	function HUDELEMENT:IsResizable()
		return true, false
	end
	-- parameter overwrites end

	function HUDELEMENT:GetDefaults()
		const_defaults["basepos"] = { x = math.Round(ScrW() * 0.5 - self.size.w * 0.5), y = ScrH() - self.margin}
		return const_defaults
	end

	function HUDELEMENT:ShouldDraw()
		local client = LocalPlayer()

		return HUDEditor.IsEditing or client:Alive() and client:IsShinigami()
	end

	function HUDELEMENT:PerformLayout()
		self.scale = self:GetHUDScale()
		self.basecolor = self:GetHUDBasecolor()
		self.element_height = element_height * self.scale
		self.margin = margin * self.scale
		self.lpw = lpw * self.scale

		BaseClass.PerformLayout(self)
	end

	function HUDELEMENT:DrawElement(i, x, y, w, h)
		-- draw bg and shadow
		self.drawer:DrawBg(x, y, w, h, self.basecolor)

		draw.AdvancedText(self.elements[i].name, "PureSkinWep", x + 10 + self.element_height, y + self.element_height * 0.5, COLOR_RED, nil, TEXT_ALIGN_CENTER, true, self.scale)

		-- draw lines around the element
		self.drawer:DrawLines(x, y, w, h, self.basecolor.a)
	end

	function HUDELEMENT:Draw()
		local tlist = {}
		local traitors = util.GetFilteredPlayers(function (ply)
			return ply:IsActive() and ply:GetTeam() == TEAM_TRAITOR
		end)
		for i = 1,table.Count(traitors) do
			table.insert(tlist, {h = self.element_height, name = traitors[i]:Nick()})
		end
		self:SetElements(tlist)
		self:SetElementMargin(self.margin)

		BaseClass.Draw(self)
	end
end
