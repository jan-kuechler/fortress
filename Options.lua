--[[ @file-author@ @file-date-iso@ @file-abbreviated-hash@ ]]--
local LibStub = LibStub
local Fortress = LibStub("AceAddon-3.0"):GetAddon("Fortress")

local AceCfgReg = LibStub("AceConfigRegistry-3.0")
local AceCfgDlg = LibStub("AceConfigDialog-3.0")
local AceCfgCmd = LibStub("AceConfigCmd-3.0")


local L = LibStub("AceLocale-3.0"):GetLocale("Fortress")
--local L = newproxy(true)
--getmetatable(L).__index = function(self, key)
--	return key
--end

local db
local appName = "Fortress"

--------
-- utility functions
--------
local function Debug(...)
--	ChatFrame1:AddMessage(strjoin(" ", "Fortess Debug:", ...), 0, 1, 0)
end

local function GetPluginSetting(pluginName, setting)
	if db.pluginUseMaster[pluginName][setting] then
		return db.masterSettings[setting]
	else
		return db.pluginSettings[pluginName][setting]
	end
end

--------
-- db getter/setter
--------
local function GetAppName(name)
	return string.gsub(name, "Fortress", "")
end

local function DefaultGet(info)
	return db[info.arg or info[#info]] 
end

local function DefaultSet(info, value)
	db[info.arg or info[#info]] = value
end

local function MasterGet(info)
	return db.masterSettings[info.arg or info[#info]]
end

local function MasterSet(info, value)
	db.masterSettings[info.arg or info[#info]] = value
	Fortress:UpdateAllObjects()
end

local function MasterColorGet(info)
	local index = info.arg or info[#info]
	local clr = db.masterSettings[index]
	return clr.r, clr.g, clr.b, clr.a
end

local function MasterColorSet(info, r, g, b, a)	
	local clr = db.masterSettings[info[#info]]
	clr.r = r
	clr.g = g
	clr.b = b
	clr.a = a
	Fortress:UpdateAllObjects()
end

local function PluginGet(info)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	if db.pluginUseMaster[name][setting] then
		return db.masterSettings[setting]
	else
		return db.pluginSettings[name][setting]
	end
end

local function PluginSet(info, value)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	if value ~= db.masterSettings[setting] then
		db.pluginUseMaster[name][setting] = false
	else
		db.pluginUseMaster[name][setting] = true
	end
	db.pluginSettings[name][setting] = value
	Fortress:UpdateObject(name)
end

local function PluginColorGet(info)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
		
	local clr
	if db.pluginUseMaster[name][setting] then
		clr = db.masterSettings[setting]
	else
		clr = db.pluginSettings[name][setting]
	end
	return clr.r, clr.g, clr.b, clr.a
end

local function PluginColorSet(info, r, g, b, a)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	db.pluginUseMaster[name][setting] = false
	
	local clr = db.pluginSettings[name][setting]
	clr.r = r
	clr.g = g
	clr.b = b
	clr.a = a
	Fortress:UpdateColor(name)
end

local function UseMasterGet(info)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	return db.pluginUseMaster[name][setting]
end

local function UseMasterSet(info, value)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	db.pluginUseMaster[name][setting] = value
end

local function PluginDisabled(info)
	local name = GetAppName(info.appName)
	return not GetPluginSetting(name, "enabled")
end

--[[ options table ]]--
local options = {
	handler = Fortress,
	get     = DefaultGet,
	set     = DefaultSet,
	name    = "Fortress",
	type    = "group",
	childGroups = "tab",
	args    = {
		general = {
			name = L["General"],
			desc = L["General options."],
			type = "group",
			order = 1,
			args = {
				enabled = {
					name = L["Enabled"],
					desc = L["Enable/disable the addon."],
					type = "toggle",
					get  = "IsEnabled",
					set  = function(info, value)
						DefaultSet(info, value)
						if value then
							Fortress:Enable()
						else
							Fortress:Disable()
						end
					end,
				},
				showAllPlugins = {
					name = L["Show all plugins"],
					desc = L["Shows all plugins at full alpha."],
					type = "execute",
					func = function(info)
						Fortress:ShowAllObjects(true)
					end,
				},
				hideAllOnMouseOut = {
					name = L["Hide all on mouse out"],
					desc = L["Show all plugins when the mouse is over one, hide them otherwise."],
					type = "toggle",
					set  = function(info, value)
						DefaultSet(info, value)
						
						if value then
							Fortress:HideAllObjects()
						else
							Fortress:ShowAllObjects()
						end
					end,
				},
				ignoreLaunchers = {
					name = L["Ignore Launchers"],
					desc = L["Do not display launcher plugins."],
					type = "toggle",
					set  = function(info, value)
						DefaultSet(info, value)
						Fortress:ToggleLaunchers()
					end,
				},
			},
		},
		masterPluginSettings = {
			name = L["Master Plugin Settings"],
			desc = L["Settings for all plugins."],
			type = "group",
			order = 2,
			get  = MasterGet,
			set  = MasterSet,
			args = {
				--[[heading = { -- outdated
					name = L["description_text"],
					type = "description",
					order = 0,
				},]]
			},
		},
	},
}

local pluginSettings = {
	{
		{
			key = "showText",
			name = L["Show Text"],
			desc = L["Show the plugin's text."],
		},
		{
			key = "showLabel",
			name = L["Show Label"],
			desc = L["Show the plugin's label."],
		},
		{
			key = "showIcon",
			name = L["Show Icon"],
			desc = L["Show the plugin's icon."],
		},
		{
			key = "showBorder",
			name = L["Show Border"],
			desc = L["Show the plugin's border."],
		},
	},
	{
		{
			key = "fontSize",
			name = L["Font Size"],
			desc = L["The text's font size."],
			min  = 5,
			max  = 20,
			step = 1,
		},
		{
			key = "blockScale",
			name = L["Block Scale"],
			desc = L["Adjusts the plugin's size."],
			min  = .1,
			max  = 2,
			step = .01,
			isPercent = true,
		},
		{
			key = "blockAlpha",
			name = L["Block Alpha"],
			desc = L["Adjusts the plugin's alpha value."],
			min  = 0,
			max  = 1,
			step = .1,
			isPercent = true,
		},
		{
			key = "blockLocked",
			name = L["Locked"],
			desc = "",
		},
	},
	{
		{
			key = "hideInCombat",
			name = L["Hide in combat"],
			desc = L["Hide this plugin in combat."],
		},
		{
			key = "hideOnMouseOut",
			name = L["Hide on mouse out"],
			desc = L["Hide this plugin until the mouse is over the frame."],
		},
		{
			key = "hideTooltipInCombat",
			name = L["Hide tooltip in combat"],
			desc = L["Hide this plugin's tooltip in combat."],
		},
		{
			key = "disableTooltip",
			name = L["Disable tooltip"],
			desc = L["Do not show this plugin's tooltip."],
		},
	},
	{
		{
			key = "fixedWidth",
			name = L["Fixed Width"],
			desc = L["Don't change the width of this plugin automatically."],
		},
		{
			key = "blockWidth",
			name = L["Width"],
			desc = L["The width of this plugin in fixed width mode."],
			min = 10,
			max = 600,
			step = 10,
			disabled = function(info)
				local name = GetAppName(info.appName)
				return not GetPluginSetting(name, "fixedWidth")
			end,
			masterDisabled = function(info)
				return not db.masterSettings.fixedWidth
			end,
		},
	},
	{
		{
			key = "borderColor",
			name = L["Border Color"],
			desc = L["The plugins border color."],
			hasAlpha = true,
		},
		{
			key = "frameColor",
			name = L["Frame Color"],
			desc = L["The plugins main color."],
			hasAlpha = true,
		},
		{
			key = "textColor",
			name = L["Text Color"],
			desc = L["The text color."],
		},
		{
			key = "labelColor",
			name = L["Label Color"],
			desc = L["The label color."],
		},
		{
			key = "unitColor",
			name = L["Suffix Color"],
			desc = L["The suffix color."],
		},
	},
}

local pluginOptions = {
	enabled = {
		name = L["Enabled"],
		desc = L["Enables or disables the plugin."],
		type = "toggle",
		get  = function(info)
			local name = GetAppName(info.appName)
			return db.pluginSettings[name].enabled
		end,
		set  = function(info, value)
			local name = GetAppName(info.appName)
			if value then
				Fortress:EnableDataObject(name)
			else
				Fortress:DisableDataObject(name)
			end
		end, 
		order = 0,
	},
}
local pluginUseMasterOptions = {}
local pluginOptionsGroup = {
	settings = {
		type = "group",
		name = L["Settings"],
		desc = L["Individual plugin settings."],
		args = pluginOptions,
		order = 1,
	},
	masterSettings = {
		type = "group",
		name = L["Select master"],
		desc = L["Select which setting should be handled individualy."],
		args = pluginUseMasterOptions,
		order = 2,
	},
}

local typeToType = {
	boolean = "toggle",
	table   = "color",
	number  = "range",
}

local function CreatePluginOptions()
	local optType = Fortress.defaults.profile.masterSettings

	for i, group in ipairs(pluginSettings) do
		local optionsGroup = {
			name   = group.name or "",
			inline = true,
			type   = "group",
			order  = i,
			args   = {},
		}
		optionsArgs = optionsGroup.args
		pluginOptions["group"..i] = optionsGroup

		local masterGroup = {
			name   = group.name or "",
			inline = true,
			type   = "group",
			order  = i,
			args   = {},   
		}
		local masterArgs = masterGroup.args
		options.args.masterPluginSettings.args["group"..i] = masterGroup
		
		local useMasterGroup = {
			name   = group.name or "",
			inline = true,
			type   = "group",
			order  = i,
			args   = {},   
		}
		useMasterArgs = useMasterGroup.args
		pluginUseMasterOptions["group"..i] = useMasterGroup

		for ii, setting in ipairs(group) do
			local key = setting.key
			local t   = typeToType[type(optType[key])]
			Debug("Type for", key, "is", t or "nil")
			
			local get, set, mget, mset
			if t == "color" then
				get = PluginColorGet
				set = PluginColorSet
				mget = MasterColorGet
				mset = MasterColorSet
			else
				get = PluginGet
				set = PluginSet
				mget = MasterGet
				mset = MasterSet
			end
			
			get = setting.get or get
			set = setting.set or set
			
			optionsArgs[key] = {
				type = t,
				name = setting.name,
				desc = setting.desc,
				get  = get,
				set  = set,
				disabled = setting.disabled,
				hidden = setting.hidden,
				hasAlpha = setting.hasAlpha,
				min  = setting.min,
				max  = setting.max,
				step = setting.step,
				isPercent = setting.isPercent,
				order = ii,
			}
			
			masterArgs[key] = {
				type = t,
				name = setting.name,
				desc = setting.desc,
				get  = mget,
				set  = mset,
				disabled = setting.masterDisabled,
				hidden = setting.hidden,
				hasAlpha = setting.hasAlpha,
				min  = setting.min,
				max  = setting.max,
				step = setting.step,
				isPercent = setting.isPercent,
				order = ii,
			}
			
			useMasterArgs[key] = {
				type = "toggle",
				name = setting.name,
				desc = L["Use the master setting for this option."],
				set  = UseMasterSet,
				get  = UseMasterGet,
				hidden = setting.hidden,
				order = ii,
			}
		end
	end
end

local blizOptions

local function ChatCmd(input)
	if not input or input:trim() == "" then
		InterfaceOptionsFrame_OpenToCategory(blizOptions)
	else
		if input:trim() == "help" then
			input = ""
		end
		AceCfgCmd.HandleCommand(self, "fortress", appName, input)
	end
end

function Fortress:RegisterOptions()
	db = assert(self.db.profile)	-- assert to ensure that AceDB:New() gets called before this function
	self.optionsFrames = {}
	
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	CreatePluginOptions()
	
	AceCfgReg:RegisterOptionsTable(appName, options)
	blizOptions = AceCfgDlg:AddToBlizOptions(appName, L["Fortress"])
	
	self:RegisterChatCommand("fortress", ChatCmd)
	self:RegisterChatCommand("ft", ChatCmd)
end

function Fortress:UpdateOptionsDbRef()
	db = self.db.profile
end

local function Swap(tab, a, b)
	Debug("Swapping", a, tab[a].name, "and", b, tab[b].name)
	local tmp = tab[a]
	tab[a] = tab[b]
	tab[b] = tmp
end

local function SortSubCategories(parent)
	local list = INTERFACEOPTIONS_ADDONCATEGORIES
	local done = true
	for i=1, #list-1 do
		if (list[i].parent == parent) and (list[i+1].parent == parent) then
			if list[i].name > list[i+1].name then
				Swap(list, i, i+1)
				done = false
			end
		end
	end
	if not done then
		SortSubCategories(parent)
	end
end

function Fortress:AddObjectOptions(name)
	local t = self.optionsFrames[name] or {}
	t.name = name
	t.desc = L["Options for %s"]:format(name)
	t.type = "group"
	t.childGroups = "tab"
	t.args = pluginOptionsGroup
	t.get  = PluginGet
	t.set  = PluginSet
	AceCfgReg:RegisterOptionsTable("Fortress"..name, t)
	AceCfgDlg:AddToBlizOptions("Fortress"..name, name, "Fortress")
	
	SortSubCategories("Fortress")
end
