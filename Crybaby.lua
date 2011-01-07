local _G = getfenv(0)
local LibStub = _G.LibStub
local Crybaby = LibStub("AceAddon-3.0"):NewAddon("Crybaby", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Crybaby")
local AceConfig = LibStub("AceConfigRegistry-3.0")
local LibSink = LibStub("LibSink-2.0")
local db

local band = _G.bit.band
local pairs, ipairs = _G.pairs, _G.ipairs
local format = _G.string.format
local twipe = _G.table.wipe

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
		tanks = {},
		all_local = false,
		report_cc = false,
		report_other = false,
		tankroles = true,
		sinkOptionsCC = {
			sink20OutputSink = "ChatFrame",
		},
		sinkOptionsOther = {
			sink20OutputSink = "ChatFrame",
		},
	},
}


-- Distinguishing CC and MD/other output settings.  LibSink requires client
-- "addons" to be of table type, but makes no use of any of their fields (with
-- one uninteresting exception).  Since the tables here merely need to be unique
-- pointers, choose some arbitrary existing ones rather then creating needless
-- empty ones.
local tagCC, tagOther = defaults.profile.sinkOptionsCC, defaults.profile.sinkOptionsOther

local build_tank_values
do
	local visual = {}
	function build_tank_values()
		twipe(visual)
		for name in pairs(db.tanks) do
			visual[name] = name
		end
		return visual
	end
end

local function getoption (info)
	local name = info[#info]
	return db[name]
end

local function setoption (info, value)
	local name = info[#info]
	db[name] = value
	local arg = info.arg
	--if arg then self[arg](self) end
end

local options = {
	type = 'group',
	args = {
		all_local = {
			type = "toggle",
			name = L["Local Output"],
			desc = L["Always print output to the local chat window, in addition to anything set in the Output sections."],
			order = 5,
			get = getoption,
			set = setoption,
		},
		report_cc = {
			type = "toggle",
			name = L["Report CC Breakage"],
			desc = L["Report breaking crowd control effects, as controlled by the Output section."],
			order = 10,
			get = getoption,
			set = setoption,
		},
		report_other = {
			type = "toggle",
			name = L["Report Other"],
			desc = L["Report other spell effects, as controlled by the Output section."],
			order = 15,
			get = getoption,
			set = setoption,
		},
		spells_cc = {
			type = 'group',
			name = L["CC Spells"],
			desc = L["Toggle spell notifications"],
			order = 20,
			get = function (i) return db.spells[i[#i]] end,
			set = function (i,v) db.spells[i[#i]] = v end,
			args = {
				output = LibSink.GetSinkAce3OptionsDataTable(tagCC),
				tanks = {
					type = 'group',
					name = L["Tanks"],
					desc = L["Who should NOT be reported for breaking crowd control."],
					order = 30,
					args = {
						role = {
							type = 'toggle',
							name = L["Include tank role"],
							desc = 'NOT IMPLEMENTED YET. ' .. L["Automatically include players marked with a tank role"],
							order = 1,
							get = function() return db.tankroles end,
							set = function(i,v) db.tankroles = v end,
							hidden=true,disabled=true,
						},
						linebreak = {
							name = '',
							type = 'description',
							cmdHidden = true,
							width = 'full',
							order = 9,
						},
						tankadd = {
							type = 'input',
							name = L["Add Tank"],
							desc = L["Names of characters who should not be reported for breaking CC."],
							dialogControl = 'EditBoxRaidMembers',
							order = 10,
							get = false,
							set = function(i,key) db.tanks[key] = true; AceConfig:NotifyChange("Crybaby") end,
						},
						tankremove = {
							type = 'select',
							name = function()
								local n = 0
								for _ in next, db.tanks do n=n+1 end
								return L["Remove Tank"]:format(n)
							end,
							desc = L["Click a name to remove them from the special tank-exception list."],
							style = 'dropdown',
							order = 11,
							values = function() return build_tank_values() end,
							get = false,
							set = function(i,key) db.tanks[key] = nil; AceConfig:NotifyChange("Crybaby") end,
						},
					},
				},
			},
		},
		spells_other = {
			type = 'group',
			name = L["Other Spells"],
			desc = L["Toggle spell notifications"],
			order = 30,
			args = {
				output = LibSink.GetSinkAce3OptionsDataTable(tagOther),
			},
		},
	},
}

options.args.spells_other.get = options.args.spells_cc.get
options.args.spells_other.set = options.args.spells_cc.set

-- Splitting these out so that CC settings don't affect MD printing, etc.
local check_for_cc, check_for_other = {}, {}

for _,k in ipairs(cc) do
	defaults.profile.spells[k] = true
	check_for_cc[k] = true
	options.args.spells_cc.args[k] = {
		type = "toggle",
		name = k,
	}
end

for _,k in ipairs(md) do
	defaults.profile.spells[k] = true
	check_for_other[k] = true
	options.args.spells_other.args[k] = {
		type = "toggle",
		name = k,
	}
end


local getcolor, geticon
do
	function getcolor(name)
		if type(name) ~= 'string' then return end
		local _, class = UnitClass(name)
		local color = class and _G["RAID_CLASS_COLORS"][class]
		local hex = color and format("|cff%02x%02x%02x", color.r*255, color.g*255, color.b*255)
		return hex
	end

	local iconlist = _G.ICON_LIST
	local iconformat = "%s0|t"
	local rt1 = _G.COMBATLOG_OBJECT_RAIDTARGET1
	local rtmask = _G.COMBATLOG_OBJECT_SPECIAL_MASK
	function geticon(flag,sinkoptions)
		if flag == nil then return end
		local localoutput, otheroutput = "", ""
		local number 

		local sink = sinkoptions.sink20OutputSink

		if band(flag, rtmask) ~= 0 then
			for i=1,8 do
				local mask = rt1 * (2 ^ (i - 1))
				local mark = (band(flag, mask) == mask)
				if mark then number = i end
			end
		end
		if not number then return end

		-- Local chat window can't use {rtX} notation
		local icon = rt1 * (number ^ (number - 1))
		local path = iconlist[number]
		localoutput = iconformat:format(path)
		if sink ~= "Channel" then
			otheroutput = localoutput
		else
			otheroutput = ("{rt%d}"):format(number)
		end
		return localoutput, otheroutput
	end
end

function Crybaby:OnInitialize()
	-- savedvars
	self.db = LibStub("AceDB-3.0"):New("CrybabyDB", defaults, "Default")
	db = self.db.profile
	if type(db.sinkOptions) == 'table' then
		-- do some rough conversion of old settings
		db.sinkOptionsCC.sink20OutputSink = db.sinkOptions.sink20OutputSink
		db.sinkOptionsOther.sink20OutputSink = db.sinkOptions.sink20OutputSink
		db.report_cc = db.sinkOptions.sink20OutputSink ~= "None"
		db.report_other = db.report_cc
		self:Print("Older settings have been converted; you may want to check the configuration now.")
		db.sinkOptions = nil
	end

	-- options
	LibStub("AceGUI-3.0-Completing-EditBox"):Register("RaidMembers", AUTOCOMPLETE_LIST_TEMPLATES.IN_GROUP)
	AceConfig:RegisterOptionsTable("Crybaby", options)
	self.optFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Crybaby", "Crybaby")
	LibStub("AceConsole-3.0"):RegisterChatCommand("crybaby", function() InterfaceOptionsFrame_OpenToCategory("Crybaby") end)

	-- savedvars for sink
	LibSink.SetSinkStorage(tagCC, self.db.profile.sinkOptionsCC)
	LibSink.SetSinkStorage(tagOther, self.db.profile.sinkOptionsOther)
end

function Crybaby:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Crybaby:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, subevent, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, spellID, spell, spellSchool, extraID, extra, extraSchool, auratype)
	if subevent == "SPELL_AURA_BROKEN_SPELL" or subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_DISPEL" then 
		if band(dstFlags, friendly) ~= 0 then return end   -- CC removed from friendly unit
		if not check_for_cc[spell] then return end         -- not a CC spell
		if not db.spells[spell] then return end            -- player doesn't want to see this CC
		local breaker = src or L["Unknown"]
		local istank = db.tanks[breaker]
		local srccolor = getcolor(src) or green
		local dstcolor = getcolor(dst) or red
		local srciconL,srciconO = geticon(srcFlags,db.sinkOptionsCC)
		local dsticonL,dsticonO = geticon(dstFlags,db.sinkOptionsCC)
		local action = extra and (L["act"]:format(extra)) or "" 
		if db.all_local then
			DEFAULT_CHAT_FRAME:AddMessage(L["cc"]:format(spell, dsticonL or "", dstcolor, dst, srciconL or "", srccolor, breaker, action))
		end
		if istank then
			return
		end
		if db.report_cc then
			LibSink.Pour(tagCC,L["cc"]:format(spell, dsticonO or "", dstcolor, dst, srciconO or "", srccolor, breaker, action))
		end
	elseif subevent == "SPELL_CAST_SUCCESS" then
		if band(dstFlags, outsider) ~= 0 then return end   -- caster not in our group
		if not check_for_other[spell] then return end      -- not an "interesting" spell
		if not db.spells[spell] then return end            -- player doesn't want to see this spell
		local caster = src or L["Unknown"]
		local target = dst or L["Unknown"]
		local srccolor = getcolor(src) or red
		local dstcolor = getcolor(dst) or green
		local srciconL,srciconO = geticon(srcFlags,db.sinkOptionsCC)
		local dsticonL,dsticonO = geticon(dstFlags,db.sinkOptionsCC)
		if db.all_local then
			DEFAULT_CHAT_FRAME:AddMessage(L["md"]:format(srciconL or "", srccolor, caster, spell, dsticonL or "", dstcolor, target))
		end
		if db.report_cc then
			LibSink.Pour(tagOther,L["md"]:format(srciconO or "", srccolor, caster, spell, dsticonO or "", dstcolor, target))
		end
	end
end
