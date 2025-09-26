--[[
-- Kui_Nameplates
-- By Kesava at curse.com
-- All rights reserved
-- Backported by: Kader at https://github.com/bkader
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = addon:NewModule("ComboPoints", addon.Prototype, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("KuiNameplates")
local _

-- coloured display name in options
mod.uiName = "|cff55aaff" .. (L["Combo points"] or "Combo points") .. "|r"

local P
local ICON_SPACING = -1 -- default fallback; replaced by P.spacing after init

local anticipationWasActive

local colours = {
	full = {1, 1, .1},
	partial = {.79, .55, .18},
	anti = {1, .3, .3},
	glowFull = {1, 1, .1, .6},
	glowPartial = {0, 0, 0, .3},
	glowAnti = {1, .1, .1, .8}
}
local sizes = {}
local defaultSizes = {}

local function ComboPointsUpdate(self)
	if self.points and self.points > 0 then
		local maxPoints = 5
		if self.points == maxPoints then
			self.colour = (P and P.colours and P.colours.full) or colours.full
			self.glowColour = (P and P.glow and ((P.colours and P.colours.glowFull) or colours.glowFull)) or nil
		else
			self.colour = (P and P.colours and P.colours.partial) or colours.partial
			self.glowColour = (P and P.glow and ((P.colours and P.colours.glowPartial) or colours.glowPartial)) or nil
		end

		for i = 1, 5 do
			if i <= self.points then
				self[i]:SetAlpha(1)
			else
				self[i]:SetAlpha(.3)
			end

			self[i]:SetVertexColor(unpack(self.colour))
			if self.glowColour then
				self.glows[i]:SetVertexColor(unpack(self.glowColour))
				self.glows[i]:Show()
			else
				self.glows[i]:Hide()
			end
		end

		self:Show()
	else
		if P and P.showWhenZero then
			-- show empty state if desired
			for i = 1, 5 do
				self[i]:SetAlpha(.3)
				local c = (P and P.colours and P.colours.partial) or colours.partial
				self[i]:SetVertexColor(unpack(c))
				if P and P.glow and P.colours and P.colours.glowPartial then
					self.glows[i]:SetVertexColor(unpack(P.colours.glowPartial))
					self.glows[i]:Show()
				else
					self.glows[i]:Hide()
				end
			end
			self:Show()
		elseif self:IsShown() then
			self:Hide()
		end
	end
end
-------------------------------------------------------------- Event handlers --
function mod:UNIT_COMBO_POINTS(event, unit)
	-- only works for player > target
	if unit ~= "player" then
		return
	end

	local f = addon:GetUnitPlate("target")

	if f and f.combopoints then
		local points = GetComboPoints("player", "target")
		f.combopoints.points = points
		f.combopoints:Update()

		if points > 0 then
			-- clear points on other frames
			for _, frame in pairs(addon.frameList) do
				if frame.kui.combopoints and frame.kui ~= f then
					self:HideComboPoints(nil, frame.kui)
				end
			end
		end
	end
end
---------------------------------------------------------------------- Target --
function mod:OnFrameTarget(msg, frame, is_target)
	if is_target then
		self:UNIT_COMBO_POINTS(nil, "player")
	end
end
---------------------------------------------------------------------- Create --
function mod:CreateComboPoints(msg, frame)
	-- create combo point icons
	frame.combopoints = CreateFrame("Frame", nil, frame.overlay)
	frame.combopoints.glows = {}
	frame.combopoints:Hide()

	local pcp
	for i = 0, 4 do
		-- create individual combo point icons
		-- size and position of first icon is set in ScaleComboPoints
		local cp = frame.combopoints:CreateTexture(nil, "ARTWORK")
		cp:SetDrawLayer("ARTWORK", 2)
		cp:SetTexture("Interface\\AddOns\\Kui_Nameplates\\Media\\combopoint-round")

		-- positioning applied in LayoutComboPoints after creation

		tinsert(frame.combopoints, i + 1, cp)
		pcp = cp

		-- and their glows
		local glow = frame.combopoints:CreateTexture(nil, "ARTWORK")

		glow:SetDrawLayer("ARTWORK", 1)
		glow:SetTexture("Interface\\AddOns\\Kui_Nameplates\\Media\\combopoint-glow")
		glow:SetPoint("CENTER", cp)

		tinsert(frame.combopoints.glows, i + 1, glow)
	end

	self:ScaleComboPoints(frame)
	self:LayoutComboPoints(frame)
	frame.combopoints.Update = ComboPointsUpdate
end
-- update/set frame sizes ------------------------------------------------------
function mod:ScaleComboPoints(frame)
	for i, cp in ipairs(frame.combopoints) do
		cp:SetSize(sizes.combopoints, sizes.combopoints)
		frame.combopoints.glows[i]:SetSize(sizes.combopoints + 8, sizes.combopoints + 8)
	end
end

-- position icons centered based on config
function mod:LayoutComboPoints(frame)
	local holder = frame.combopoints
	if not holder then return end
	local spacing = (P and P.spacing) or ICON_SPACING
	local size = sizes.combopoints or 6.5
	local total = (5 * size) + (4 * spacing)

	-- clear existing anchors
	for i, cp in ipairs(holder) do
		cp:ClearAllPoints()
	end
	for i, glow in ipairs(holder.glows) do
		glow:ClearAllPoints()
	end

	local pos = (P and P.position) or "BOTTOM"
	local ox = (P and P.offsetX) or 0
	local oy = (P and P.offsetY) or -3

	if pos == "TOP" or pos == "BOTTOM" then
		-- horizontal layout
		local anchorPoint = pos == "TOP" and "TOP" or "BOTTOM"
		local yoff = oy
		local startX = -total/2 + (size/2)
		for i, cp in ipairs(holder) do
			local x = startX + (i-1) * (size + spacing)
			cp:SetPoint(anchorPoint, frame.overlay, anchorPoint, x + ox, yoff)
			holder.glows[i]:SetPoint("CENTER", cp)
		end
	else
		-- vertical layout (LEFT/RIGHT)
		local anchorPoint = pos == "RIGHT" and "RIGHT" or "LEFT"
		local xoff = ox
		local startY = total/2 - (size/2)
		for i, cp in ipairs(holder) do
			local y = startY - (i-1) * (size + spacing)
			cp:SetPoint(anchorPoint, frame.overlay, anchorPoint, xoff, y + oy)
			holder.glows[i]:SetPoint("CENTER", cp)
		end
	end
end
------------------------------------------------------------------------ Hide --
function mod:HideComboPoints(msg, frame)
	if frame.combopoints then
		frame.combopoints.points = nil
		frame.combopoints:Update()
	end
end
---------------------------------------------------- Post db change functions --
mod:AddConfigChanged("enabled", function(v) mod:Toggle(v) end)
mod:AddConfigChanged(
	"scale",
	function(v)
		sizes.combopoints = defaultSizes.combopoints * v
	end,
	function(f, v)
		mod:ScaleComboPoints(f)
		mod:LayoutComboPoints(f)
	end
)
mod:AddConfigChanged("spacing", nil, function(f) mod:LayoutComboPoints(f) end)
mod:AddConfigChanged("position", nil, function(f) mod:LayoutComboPoints(f) end)
mod:AddConfigChanged("offsetX", nil, function(f) mod:LayoutComboPoints(f) end)
mod:AddConfigChanged("offsetY", nil, function(f) mod:LayoutComboPoints(f) end)
mod:AddConfigChanged("glow", nil, function(f) if f.combopoints then f.combopoints:Update() end end)
mod:AddConfigChanged({"colours","full"}, nil, function(f) if f.combopoints then f.combopoints:Update() end end)
mod:AddConfigChanged({"colours","partial"}, nil, function(f) if f.combopoints then f.combopoints:Update() end end)
-------------------------------------------------------------------- Register --
function mod:GetOptions()
	return {
		enabled = {
			type = "toggle",
			name = L["Show combo points"],
			desc = L["Show combo points on the target"],
			order = 0
		},
		scale = {
			type = "range",
			name = L["Icon scale"],
			desc = L["The scale of the combo point icons and glow"],
			order = 5,
			min = 0.1,
			softMin = 0.5,
			softMax = 2
		},
		spacing = {
			type = "range",
			name = "Spacing",
			order = 10,
			min = -8,
			max = 16,
			step = 0.5
		},
		position = {
			type = "select",
			name = "Position",
			order = 11,
			values = { TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right" }
		},
		offsetX = {
			type = "range",
			name = "X Offset",
			order = 12,
			min = -50,
			max = 50,
			step = 0.5
		},
		offsetY = {
			type = "range",
			name = "Y Offset",
			order = 13,
			min = -50,
			max = 50,
			step = 0.5
		},
		showWhenZero = {
			type = "toggle",
			name = "Show when zero",
			order = 14
		},
		glow = {
			type = "toggle",
			name = "Show glow",
			order = 15
		},
		colours = {
			type = "group",
			name = "Colours",
			inline = true,
			order = 20,
			args = {
				full = { type = "color", name = "Full points", order = 1 },
				partial = { type = "color", name = "Partial points", order = 2 },
			}
		}
	}
end

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {profile = {
		enabled = true,
		scale = 1,
		spacing = -1,
		position = "BOTTOM",
		offsetX = 0,
		offsetY = -3,
		showWhenZero = false,
		glow = true,
		colours = {
			full = {1,1,.1},
			partial = {.79,.55,.18},
			glowFull = {1,1,.1,.6},
			glowPartial = {0,0,0,.3}
		}
	}})
	defaultSizes.combopoints = 6.5

	-- scale size with user option
	self.configChangedFuncs.scale.ro(self.db.profile.scale)
	P = self.db.profile
	ICON_SPACING = P.spacing or ICON_SPACING

	addon:InitModuleOptions(self)
	mod:SetEnabledState(self.db.profile.enabled)
end

function mod:OnEnable()
	P = self.db.profile
	ICON_SPACING = P.spacing or ICON_SPACING
	self:RegisterMessage("KuiNameplates_PostCreate", "CreateComboPoints")
	self:RegisterMessage("KuiNameplates_PostHide", "HideComboPoints")
	self:RegisterMessage("KuiNameplates_PostTarget", "OnFrameTarget")

	self:RegisterEvent("UNIT_COMBO_POINTS")

	for _, frame in pairs(addon.frameList) do
		if not frame.combopoints then
			self:CreateComboPoints(nil, frame.kui)
		else
			self:ScaleComboPoints(frame.kui)
			self:LayoutComboPoints(frame.kui)
		end
	end
end

function mod:OnDisable()
	self:UnregisterEvent("UNIT_COMBO_POINTS")

	for _, frame in pairs(addon.frameList) do
		self:HideComboPoints(nil, frame.kui)
	end
end