local _G = getfenv(0)
local LibStub = _G.LibStub
local Crybaby = LibStub("AceAddon-3.0"):NewAddon("Crybaby", "AceConsole-3.0", "AceEvent-3.0", "LibSink-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Crybaby")
local db

local band = _G.bit.band
local ipairs = _G.ipairs
local format = _G.string.format

local GetSpellInfo = _G.GetSpellInfo
local UnitClass = _G.UnitClass
local UnitGUID = _G.UnitGUID
local UnitExists = _G.UnitExists
local CreateFrame = _G.CreateFrame

local green = _G.GREEN_FONT_COLOR_CODE
local red = _G.RED_FONT_COLOR_CODE
local friendly = _G.COMBATLOG_OBJECT_REACTION_FRIENDLY
local outsider = _G.COMBATLOG_OBJECT_AFFILIATION_OUTSIDER

local cc = {
	(GetSpellInfo(118)),   -- 118   Polymorph
	(GetSpellInfo(9484)),  -- 9484  Shackle Undead
	(GetSpellInfo(2637)),  -- 2637  Hibernate
	(GetSpellInfo(3355)),  -- 3355  Freezing Trap
	(GetSpellInfo(6358)),  -- 6358  Seduction
	(GetSpellInfo(6770)),  -- 6770  Sap
	(GetSpellInfo(20066)), -- 20066 Repentance
	(GetSpellInfo(51514)), -- 51514 Hex
	(GetSpellInfo(76780)), -- 76780 Bind Elemental
	}

local md = {
	(GetSpellInfo(34477)), -- 34477 Misdirection
	(GetSpellInfo(49016)), -- 57934 Unholy Frenzy
	(GetSpellInfo(57934)), -- 57934 Tricks of the Trade
	}

local defaults = {
	profile = {
		spells = {},
		sinkOptions = {
			sink20OutputSink = "ChatFrame",
		},
	},
}

local options = {
	type = 'group',
	args = {
		output = Crybaby:GetSinkAce3OptionsDataTable(),
		spells = {
			type = 'group',
			name = L["Spells"],
			desc = L["Toggle spell notifications"],
			order = 20,
			args = {},
		},
	},
}

for _,k in ipairs(cc) do
	defaults.profile.spells[k] = true
	options.args.spells.args[k] = {
		type = "toggle",
		name = k,
		get = function () return db.spells[k] end,
		set = function (i,v) db.spells[k] = v end,
	}
end

for _,k in ipairs(md) do
	defaults.profile.spells[k] = true
	options.args.spells.args[k] = {
		type = "toggle",
		name = k,
		get = function () return db.spells[k] end,
		set = function (i,v) db.spells[k] = v end,
	}
end


local getcolor, geticon
do
	function getcolor(name)
		local _, class = UnitClass(name)
		local color = class and _G["RAID_CLASS_COLORS"][class]
		local hex = color and format("|cff%02x%02x%02x", color.r*255, color.g*255, color.b*255)
		return hex
	end

	local iconlist = _G.ICON_LIST
	local iconformat = "%s0|t"
	local rt1 = _G.COMBATLOG_OBJECT_RAIDTARGET1
	local rtmask = _G.COMBATLOG_OBJECT_SPECIAL_MASK
	function geticon(flag)
		local output
		local number 

		local sink = db.sinkOptions.sink20OutputSink

		if band(flag, rtmask) ~= 0 then
			for i=1,8 do
				local mask = rt1 * (2 ^ (i - 1))
				local mark = (band(flag, mask) == mask)
				if mark then number = i end
			end
		end

		if number and sink ~= "Channel" then
			local icon = rt1 * (number ^ (number - 1))
			local path = iconlist[number]
			output = iconformat:format(path)
		elseif number then
			output = ("{rt%s}"):format(number)
		else
			output = ""
		end
		return output
	end
end

function Crybaby:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("CrybabyDB", defaults, "Default")
	db = self.db.profile
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Crybaby", options)
	self.optFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Crybaby", "Crybaby")
	self:SetSinkStorage(self.db.profile.sinkOptions)
	LibStub("AceConsole-3.0"):RegisterChatCommand( "crybaby", function() InterfaceOptionsFrame_OpenToCategory("Crybaby") end )
end

function Crybaby:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Crybaby:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, subevent, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, spellID, spell, spellSchool, extraID, extra, extraSchool, auratype)
	if subevent == "SPELL_AURA_BROKEN_SPELL" or subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_DISPEL" then 
		if band(dstFlags, friendly) == 0 then
			for k,v in ipairs(cc) do
				if v == spell and db.spells[spell] then
					local srccolor = getcolor(src) or green
					local dstcolor = getcolor(dst) or red
					local srcicon = geticon(srcFlags) or ""
					local dsticon = geticon(dstFlags) or ""
					local breaker = src and src or L["Unknown"]
					local action = extra and (L["act"]:format(extra)) or "" 
					self:Pour(L["cc"]:format(spell, dsticon, dstcolor, dst, srcicon, srccolor, breaker, action))
					break
				end
			end
		end
	elseif subevent == "SPELL_CAST_SUCCESS" then
		if band(dstFlags, outsider) == 0 then
			for k,v in ipairs(md) do
				if v == spell and db.spells[spell] then
					local srccolor = getcolor(src) or red
					local dstcolor = getcolor(dst) or green
					local srcicon = geticon(srcFlags) or ""
					local dsticon = geticon(dstFlags) or ""
					self:Pour(L["md"]:format(srcicon, srccolor, src, spell, dsticon, dstcolor, dst))
				end
			end
		end
	end
end
